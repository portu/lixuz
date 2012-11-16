#!/usr/bin/perl
# Daily cronjob for Lixuz

# -- INIT --
use strict;
use warnings;
use 5.010;
use POSIX qw(nice); nice(10); # Be nice
use FindBin;
use File::stat;
use DBI;
use Cwd;
use Try::Tiny;
use constant {
    true => 1,
    false => 0
};

use lib $FindBin::RealBin.'/../lib/';
# Lixuz doesn't like not being in its own dir when initializing
chdir($FindBin::RealBin.'/..');
my $title = 'LIXUZ_Daily_Cron ['.getcwd.']';

my $currTitle;
my $return       = false;
my $verbosity    = 0;
my $runAll       = false;
my $skipIndex    = false;
my $onlyIndex    = false;
my $reIndex      = false;
my $paramErrors  = 0;
my $strictParams = 0;
my %options;

sub title
{
    $currTitle = shift;
    $0 = $title .' - '.$currTitle;
    if ($verbosity)
    {
        print $0."\n";
    }
}
sub tryRun (&)
{
    my $sub = shift;
    try
    {
        $sub->();
    }
    catch
    {
        if (/SUB_SKIPPED/)
        {
            return;
        }
        warn($_);
        warn("The above error occurred during the step \"$currTitle\"\nWill attempt to continue anyway.\n");
        $return = 1;
    };
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

foreach (@ARGV)
{
	given($_)
	{
		when('--noindex')
		{
			$skipIndex = true;
		}

		when('--verbose')
		{
			$verbosity++;
		}

		when('--runall')
		{
			$runAll++;
		}

        when('--onlyindex')
        {
            $onlyIndex = true;
            $title = 'Lixuz indexer';
        }

        when('--reindex')
        {
            $reIndex = true;
        }

        when(/^--indexer[-_]skip(files|articles)$/)
        {
            s/^--//;
            s/^-/_/g;
            $options{$_} = 1;
        }

        when('--strict')
        {
            $strictParams = 1;
        }

		default
		{
            $paramErrors++;
			warn("Unknown parameter: $_\n");
		}
	}
}

die("Dying because of unknown parameters (with --strict enabled)\n") if($strictParams && $paramErrors);

title('init');

silent
{
    require LIXUZ;
};
use LIXUZ::HelperModules::Scripts qw(fakeC);
use LIXUZ::HelperModules::Indexer;

my $fakeC  = fakeC();

if(ref($fakeC->config->{'Model::LIXUZDB'}->{'connect_info'}) eq 'ARRAY')
{
    die("Old-style config. Unable to continue.\n");
}
my $DBSTR  = $fakeC->config->{'Model::LIXUZDB'}->{'connect_info'}->{dsn};
my $DBUser = $fakeC->config->{'Model::LIXUZDB'}->{'connect_info'}->{user};
my $DBPwd  = $fakeC->config->{'Model::LIXUZDB'}->{'connect_info'}->{password};
my $dbh = DBI->connect($DBSTR,$DBUser,$DBPwd);

my (undef,undef,undef,$mday,undef,undef,$wday,undef,undef) = localtime;

# Clean up captchas
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('captcha cleaning');
    $dbh->do('DELETE FROM lz_live_captcha WHERE UNIX_TIMESTAMP() > (UNIX_TIMESTAMP(created_date)+7400);');
};

# Clean up old cached files
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('imgcache cleaning');
    my $path = $fakeC->config->{LIXUZ}->{file_path};
    while(my $f = glob($path.'/*.imgcache'))
    {
        my $stat = stat $f;
        if(defined $stat->atime && $stat->atime > $stat->mtime)
        {
            my $oneWeekAgo = time() - (86_500*7);
            if ($stat->atime < $oneWeekAgo)
            {
                unlink($f);
            }
        }
    }
};

# ---
# Clean up errors in the DB
# ---

# Self-referencing relationships
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('self-ref relationship cleaning');
    $dbh->do('DELETE FROM lz_article_relations WHERE article_id=related_article_id;');
};

# Missing statuses
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('missing statuses');
    $dbh->do('UPDATE lz_article SET status_id=4 WHERE status_id IS NULL;');
};

# Folders without a single field, and folders missing essential fields
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('missing fields');
    my $rootFolders = $dbh->selectall_arrayref('SELECT folder_id FROM lz_folder WHERE parent IS NULL');
    foreach my $folder (@{$rootFolders})
    {
        $folder = $folder->[0];
        my $content = $dbh->selectall_arrayref('SELECT object_id from lz_field_module WHERE object_id='.$folder.' AND module="folders"');
        if ($content && @{$content})
        {
            # Verify that the essential folder and template_id fields are present
            my @fields = qw(folder template_id);
            my $fno = 20;
            foreach my $field (@fields)
            {
                $fno++;

                my $id = $dbh->selectall_arrayref('SELECT field_id FROM lz_field WHERE inline="'.$field.'"');
                next if (not $id or not $id->[0]);
                $id = $id->[0]->[0];
                next if (not defined $id or not length $id);
                my $existingID = $dbh->selectall_arrayref('SELECT field_id FROM lz_field_module WHERE module="folders" AND object_id='.$folder.' AND field_id='.$id);
                next if ($existingID and defined $existingID->[0]);
                $dbh->do('INSERT INTO lz_field_module (field_id,module,object_id,position,enabled) VALUES ('.$id.',"folders",'.$folder.','.$fno.',1)');
            }
        }
        else
        {
            my @fields = qw(title lead author body publish_time expiry_time status_id folder template_id);
            my $fno = 0;
            foreach my $field (@fields)
            {
                $fno++;

                my $id = $dbh->selectall_arrayref('SELECT field_id FROM lz_field WHERE inline="'.$field.'"');
                next if (not $id or not $id->[0]);
                $id = $id->[0]->[0];
                next if (not defined $id or not length $id);
                $dbh->do('INSERT INTO lz_field_module (field_id,module,object_id,position,enabled) VALUES ('.$id.',"folders",'.$folder.','.$fno.',1)');
            }
        }
    }
};
# Missing STATUSCHANGE_*
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('missing statuschange entries');
    my $statuses = $dbh->selectall_arrayref('SELECT status_id FROM lz_status');
    foreach my $status (@{$statuses})
    {
        $status = $status->[0];
        my $existing = $dbh->selectall_arrayref('SELECT action_id FROM lz_action WHERE action_path="STATUSCHANGE_'.$status.'"');
        if ($existing && @{$existing})
        {
            next;
        }
        $dbh->do('INSERT INTO lz_action (action_path) VALUES ("STATUSCHANGE_'.$status.'")');
    }
};
# Missing WORKFLOW_REASSIGN_TO_ROLE_*
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('missing workflow-reassign ACL entries');
    my $roles = $dbh->selectall_arrayref('SELECT role_id FROM lz_role');
    foreach my $role (@{$roles})
    {
        $role = $role->[0];
        my $existing = $dbh->selectall_arrayref('SELECT action_id FROM lz_action WHERE action_path="WORKFLOW_REASSIGN_TO_ROLE_'.$role.'"');
        if ($existing && @{$existing})
        {
            next;
        }
        $dbh->do('INSERT INTO lz_action (action_path) VALUES ("WORKFLOW_REASSIGN_TO_ROLE_'.$role.'")');
    }
};
# Missing lz_action entries
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

	title('missing lz_action entries');
	my $i18n = LIXUZ::HelperModules::I18N->new('lixuz','en_US',$fakeC->path_to('i18n','locale')->stringify);
	my %actionPaths = LIXUZ::Schema::LzAction->getPathsHash($i18n);
	foreach my $k (keys %actionPaths)
	{
		$fakeC->model('LIXUZDB::LzAction')->find_or_create({ action_path => $k });
	}
};
# Article issues
tryRun
{
    die('SUB_SKIPPED') if $onlyIndex;

    title('article issues');
    my %seen;
    my $folders = $fakeC->model('LIXUZDB::LzArticleFolder')->search({ primary_folder => 1});
    while(my $f = $folders->next)
    {
        my $id = $f->article_id.'-'.$f->revision;
        if ($seen{$id})
        {
            $f->set_column('primary_folder',0);
            $f->update();
        }
        else
        {
            $seen{$id} = true;
        }
    }
};

# ---
# Make sure the search index is up to date
# ---
tryRun
{
	if (!$skipIndex)
	{
		title('indexing (init)');

		my $internalIndexer = LIXUZ::HelperModules::Indexer->new(config => $fakeC->config->{'LIXUZ'}->{'indexer'}, mode => 'internal', c => $fakeC, reindex => $reIndex);
		my $liveIndexer = LIXUZ::HelperModules::Indexer->new(config => $fakeC->config->{'LIXUZ'}->{'indexer'}, mode => 'external', c => $fakeC, reindex => $reIndex);

        tryRun
        {
            die('SUB_SKIPPED') if $options{indexer_skiparticles};

            title('indexing (articles)');
            my $allArts = $fakeC->model('LIXUZDB::LzArticle')->page(1);
            my $pager = $allArts->pager;
            foreach my $page ($pager->first_page..$pager->last_page)
            {
                my $arts = $allArts->page($page);
                while(my $art = $arts->next)
                {
                    if ($art->status_id == 2)
                    {
                        $liveIndexer->add_ifmissing($art);
                    }
                    $internalIndexer->add_ifmissing($art);
                }
                # Commit changes now to avoid using too much memory This might be
                # somewhat slower than bulk committing everything at the end, but it
                # ensures somewhat consistent memory usage, no matter the size of the
                # DB
                $liveIndexer->commit_ifneeded;
                $internalIndexer->commit_ifneeded;
            }
        };

        tryRun
        {
            die('SUB_SKIPPED') if $options{indexer_skipfiles};

            title('indexing (files)');
            my $allFiles = $fakeC->model('LIXUZDB::LzFile')->page(1);
            my $pager = $allFiles->pager;
            my $added = 0;
            foreach my $page ($pager->first_page..$pager->last_page)
            {
                my $files = $allFiles->page($page);
                while(my $file = $files->next)
                {
                    if ($internalIndexer->add_ifmissing($file))
                    {
                        $added++;
                    }
                }
                if ($added > 20)
                {
                    # Commit changes now to avoid using too much memory This might be
                    # somewhat slower than bulk committing everything at the end, but it
                    # ensures somewhat consistent memory usage, no matter the size of the
                    # DB
                    $internalIndexer->commit_ifneeded;
                    $added = 0;
                }
            }
        };

		title('indexing (committing)');
		# Commit, and tell the indexer to optimize the index while we're at it
		$liveIndexer->commit(1);
		$internalIndexer->commit(1);
	}
};

exit($return) if $onlyIndex;


# ===
# Weekly chunk
# ===
if ($wday == 1 || $runAll)
{
    $title =~ s/Daily/Weekly/g;
    tryRun
    {
        title('Article sanitychecks');
        my $arts = $fakeC->model('LIXUZDB::LzArticle');
        while(my $art = $arts->next)
        {
			# Articles without workflows will be sort of lost within the system
            if(not $art->workflow)
            {
                my $wf = $fakeC->model('LIXUZDB::LzWorkflow')->create({
                        article_id => $art->article_id,
                        revision => $art->revision,
                        assigned_by => 1,
                        assigned_to_user => 1,
                    });
                $wf->update();
            }
			# Articles without revision control metadata will not be editable
			if(not $art->revisionMeta)
			{
				my $isLatest = false;
				try
				{
					my $latest = $fakeC->model('LIXUZDB::LzArticle')->search({ article_id => $art->article_id }, { order_by => 'publish_time DESC' });
					if ($latest->first->revision == $art->revision)
					{
						$isLatest = 1;
					}
				};
				my $rm = $fakeC->model('LIXUZDB::LzRevision')->create({
						type => 'article',
						type_revision => $art->revision,
						type_id => $art->article_id,
						committer => 1,
						is_latest => $isLatest,
					});
				$rm->update();
			}
			# Articles without a primary folder won't list the neccessary fields
			if(not $art->primary_folder)
			{
				if ($art->folders && $art->folders->count)
				{
					my $newpr = $art->folders->first;
					$newpr->set_column('primary_folder',1);
					$newpr->update();
				}
				else
				{
					my $f;
					try
					{
						$f = $fakeC->model('LIXUZDB::LzFolder')->search(undef, { order_by => 'folder_id ASC' })->first;
						my $newpr = $fakeC->model('LIXUZDB::LzArticleFolder')->create({
								article_id => $art->article_id,
								revision => $art->revision,
								folder_id => $f->folder_id,
								primary_folder => 1
							});
						$newpr->update;
					}
					catch
					{
						my $first = $_;
						try
						{
							warn("Failed to create LzArticleFolder for article ".$art->article_id.'/'.$art->revision." and folder_id ".$f->folder_id.': '.$_);
						}
						catch
						{
							warn("Crash during LzArticleFolder creation: $first\n$_");
						};
					};
				}
			}
        }
    };
    tryRun
	{
		title('Tree recursion checks');
		foreach my $type (qw(LzFolder LzCategory))
		{
			my $objects = $fakeC->model('LIXUZDB::'.$type);
			while(my $f = $objects->next)
			{
				next if not $f->parent;
				my $p = $f;
				while($p = $p->parent)
				{
					next if not $p->parent;
					if ($p->id == $f->id)
					{
						# Invalid (recursive) relationship. Move the object to the root of the tree
						# to resolve it
						$f->set_column('parent',undef);
						$f->update();
						last;
					}
				}
			}
		}
        title('Tree root checks');
		foreach my $type (qw(LzFolder LzCategory))
		{
			my $objects = $fakeC->model('LIXUZDB::'.$type);
			while(my $f = $objects->next)
			{
                my $foundRoot = false;
                my $loopC;
				next if not $f->parent;
				my $p = $f;
				while($p = $p->parent)
				{
                    if(not $p->parent)
                    {
                        $foundRoot = true;
                        last;
                    }
                    $loopC++;
                    if ($loopC > 99)
                    {
                        # Depth too great, move it
                        last;
                    }
				}
                if(not $foundRoot)
                {
                    # Move this object to the root of the tree
                    $f->set_column('parent',undef);
                    $f->update();
                }
			}
		}
	};
}

# ===
# Monthly chunk
# ===
if ($mday == 1 || $runAll)
{
    $title =~ s/(Daily|Weekly)/Monthly/g;
}
exit($return);
