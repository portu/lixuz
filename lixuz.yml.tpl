---
# Lixuz configuration file.
# This file is in the YAML format. "man yaml" for syntax information.
#
# Note:
# All paths supplied here needs to be unique for the site, multiple
# sites can not share data or temp directories
# -- Don't use this file to create your initial config file. Use ./scripts/lixuz_install.pl --

# Database configuration
Model::LIXUZDB:
    connect_info:
        # DBI string
        dsn: dbi:mysql:dbname=[DBNAME]
        # Username
        user: [DBUSER]
        # Password
        password: [DB_PASSWD]

# Session storage location, path to a file where temporary Lixuz session
# information will be stored
session:
    storage: [SESSION_STORAGE]

# Lixuz memcached configuration
Plugin::Cache:
    backend:
        # Memcached server addresses
        servers:
            - [MEMCACHED_SERVER]
        # The memcached namespace, needs to be unique to this instance of Lixuz
        # to avoid collisions when sharing a server with other Lixuz instances
        namespace: [MEMCACHED_NAMESPACE]
# Lixuz template directories
View::Mason:
    # Temporary directory for storing Mason object-files
    data_dir: [MASON_DATADIR]
    comp_root:
        -
            - root
            # Path to the root/ directory in the Lixuz tree
            - [LIXUZ_ROOT]
        -
            - templates
            # Path to the template storage directory
            - [TEMPLATE_PATH]

LIXUZ:
    # Temporary Lixuz files
    temp_path: [TMP_PATH]
    # User uploaded files
    file_path: [FILE_PATH]
    # User uploaded templates
    template_path: [TEMPLATE_PATH]
    # The default 'From' e-mail used in Lixuz
    from_email: [FROM_EMAIL]
    # Set email_to_override to an email address if you want to redirect ALL
    # e-mail to that address instead of the address it would otherwise have been sent to.
    email_to_override: [EMAIL_TO_OVERRIDE]
    # Set this to true (1) if you want to enable the compatibility interface for
    # retreiving files. This is a security risk and should only ever be used on
    # legacy Lixuz sites.
    files_compat: [FILES_COMPAT]
    # This is a list of RSS sources that should be available from the
    # RSSImporter. Leave empty if you don't need any.
    rss_sources:
    # The default is to have articles in the RSSImporter be inactive, if you
    # set this to 1 then they will be active by default, and you will have
    # to deactivate an article manually if you don't want it to be active.
    rssImportActiveDefault: [RSS_IMPORT_ACTIVE_DEFAULT]
    # Default URL definitions, see docs/URLs.pod.
    # Note that "%" must be escaped as "\%"
    category_url: [DEFAULT_URL_CATEGORY]
    article_url: [DEFAULT_URL_ARTICLE]
    # If you want Lixuz to log errors from the client code (javascript), set this
    # to 1
    clientErrorLog: [CLIENT_ERROR_LOG]
    # If you want Lixuz to log to a file instead of outputting to STDERR (ie. to
    # get Lixuz logs separate from Apache/Nginx logs), set this option to
    # the path to the logfile you want to output to.
    logToFile: [LOG_TO_FILE]
    # Indexer configuration
    indexer:
        language: [INDEXER_LANGUAGE]
        indexFiles: [INDEXER_STORAGE_PATH]

# vim: set ft=yaml :
