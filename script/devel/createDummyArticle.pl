#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Try::Tiny;
use Getopt::Long;
use Cwd qw(realpath);
use 5.010;
use lib "$FindBin::RealBin/../../lib/";
use LIXUZ::HelperModules::Scripts qw(fakeC);
use Text::Lorem;

my $folderID;
my $templateID;
my $statusID = 2;
my $noART = 1;
my $autoImg = 0;
my $minImg = 0;

my $usage = "Usage: ./createDummyArticle.pl OPTIONS

 Options:
 --folderid FOLDER_ID         Set the folder for the article
 --template TEMPLATE_ID       Set the template for the article. TEMPLATE_ID is an int
                              or a comma-separated list of templates to select at random.
 --status STATUS_ID           Set the status for the article (default: live/$statusID)
 --no INT                     Number of articles to create (default: 1)
 --autoimg                    Automatically assign a random number of images
                              (0-7) to the article. Image 1 always gets spot 1,
                              and the following images get random spots between
                              2 and 10.
 --requireimg (NO=1)          Same as autoimg, but guarantees at least NO (or 1, if NO
                              is omitted) image per article

 --folderid is required\n";

GetOptions(
    'folderid|folder_id=i' => \$folderID,
    'templateid|template|template_id=s' => \$templateID,
    'status|statusid|status_id=i' => \$statusID,
    'no=i' => \$noART,
    'autoimg' => \$autoImg,
    'requireimg:i' => sub
    {
        shift;
        $minImg = shift;
        $minImg //= 1;
        $autoImg = 1;
    },
    'h|help' => sub
    {
        print $usage;
        exit(0);
    },
) or die($usage);

if (defined($templateID) && $templateID !~ /^(\d+,?)+/)
{
    die("Invalid --template\n");
}

if(not defined $folderID)
{
    die($usage);
}

# Run a piece of code in silence
sub silent(&)
{
    my $cref = shift;
    my $err;
    no warnings;
    open(STDOUT_SAVED,'>&STDOUT');
    open(STDERR_SAVED,'>&STDERR');
    open(STDOUT,'>','/dev/null');
    open(STDERR,'>','/dev/null');
    try
    {
        $cref->();
    }
    catch
    {
        $err = $_;
    };
    open(STDOUT,'>&STDOUT_SAVED');
    open(STDERR,'>&STDERR_SAVED');
    use warnings;
    die($err) if $err;
}

$| = 1;

print "Initializing LIXUZ...";
# Lixuz doesn't like not being in its own dir when initializing
chdir(realpath($FindBin::RealBin.'/../../'));
unshift(@INC,realpath($FindBin::RealBin.'/../../lib'));
silent
{
    require LIXUZ;
};
print "done\n";

my $c = fakeC();

print "Creating dummy articles...";
for(my $i = 0; $i < $noART; $i++)
{
    silent
    {
        my $lipsum = Text::Lorem->new;
        my $title = ucfirst(lc($lipsum->words( randBetween(2,5) )));
        my $bodyLen = randBetween(5,15);
        my $body = '';
        while($bodyLen--)
        {
            $body .= '<p>'.$lipsum->sentences(randBetween(5,15)).'</p>';
        }
        my $template = $templateID;
        if (defined($template) && $template =~ /\S/)
        {
            my @templates = split(/,/, $template);
            $template = $templates[ int(rand(scalar(@templates))) ];
        }
        my $art = $c->model('LIXUZDB::LzArticle')->create({
                title        => $title,
                body         => $body,
                lead         => $lipsum->sentences(randBetween(4,15)),
                author       => 'Dummy Article Generator',
                template_id  => $template,
                status_id    => $statusID,
                revision     => 0,
                publish_time => \'now()',
            });
        $c->model('LIXUZDB::LzWorkflow')->create({
                article_id       => $art->article_id,
                revision         => 0,
                assigned_to_user => 1,
                assigned_by      => 1,
            });
        $c->model('LIXUZDB::LzRevision')->create({
                type                => 'article',
                type_revision       => 0,
                type_id             => $art->article_id,
                is_latest_in_status => 1,
                committer           => 1,
            });
        $c->model('LIXUZDB::LzArticleFolder')->create({
                article_id     => $art->article_id,
                folder_id      => $folderID,
                revision       => 0,
                primary_folder => 1,
            });
        if ($autoImg)
        {
            my %taken;
            my $maxImg = 7;
            if ($maxImg < $minImg)
            {
                $maxImg = $minImg;
            }
            my $images = randBetween($minImg,$maxImg);
            my $usedImages = {};
            while($images > 0)
            {
                $images--;

                my $spot = 1;
                
                for(my $t = 0; $taken{$spot} && $t < 30; $t++)
                {
                    $spot = randBetween(1,10);
                }
                my $file = randomImg($usedImages);
                next if not defined $file;
                next if $taken{$spot};
                $c->model('LIXUZDB::LzArticleFile')->create({
                        article_id => $art->article_id,
                        revision => 0,
                        file_id => $file,
                        spot_no => $spot,
                    });
                $taken{$spot} = 1;
            }
        }
    };
    print ".";
}
print "done\n";

sub randomImg
{
    my $used = shift;
    my $files = $c->model('LIXUZDB::LzFile')->search({
            status => 'Active',
        }, { order_by => \'RAND()' });
    while(my $f = $files->next)
    {
        if ($used->{ $f->file_id })
        {
            next;
        }
        if ($f->is_image)
        {
            $used->{$f->file_id} = 1;
            return $f->file_id;
        }
    }
}

sub randBetween
{
    my $min = shift;
    my $max = shift;
    $max++;

    my $no = -1;

    while($no < $min)
    {
        $no = int(rand($max));
    }
    return $no;
}
