package Amon2::Setup::Flavor::Takuji;
use 5.016_001;
use strict;
use warnings;

our $VERSION = '0.01';

use parent qw(Amon2::Setup::Flavor::Basic);
use Amon2::Setup::Flavor::Minimum;

sub write_templates {
    my ($self, $base) = @_;
    $base ||= 'tmpl';

    $self->write_file("$base/index.tt", <<'...');
[% WRAPPER 'include/layout.tt' %]

<h1><% $module %></h1>


[% END %]
...

    $self->write_file("$base/include/layout.tt", <<'...');
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
    <title>[% title || '<%= $dist %>' %]</title>
    <meta http-equiv="Content-Style-Type" content="text/css" />
    <meta http-equiv="Content-Script-Type" content="text/javascript" />
    <meta name="viewport" content="width=device-width, minimum-scale=1.0, maximum-scale=1.0" />
    <meta name="format-detection" content="telephone=no" />
    <% $tags %>
    <link href="[% static_file('/static/css/main.css') %]" rel="stylesheet" type="text/css" media="screen" />
    <script src="[% static_file('/static/js/main.js') %]"></script>
    <!--[if lt IE 9]>
        <script src="http://html5shiv.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->
</head>
<body[% IF bodyID %] id="[% bodyID %]"[% END %]>
    <div class="navbar navbar-fixed-top">
        <div class="navbar-inner">
            <div class="container">
                <a class="brand" href="#"><% $dist %></a>
                <div class="nav-collapse">
                    <ul class="nav">
                        <li class="active"><a href="#">Home</a></li>
                        <li><a href="#">Link</a></li>
                        <li><a href="#">Link</a></li>
                        <li><a href="#">Link</a></li>
                    </ul>
                </div>
            </div>
        </div><!-- /.navbar-inner -->
    </div><!-- /.navbar -->
    <div class="container">
        <div id="main">
            [% content %]
        </div>
        <footer class="footer">
            Powered by <a href="http://amon.64p.org/">Amon2</a>
        </footer>
    </div>
</body>
</html>
...

    $self->write_file("$base/include/pager.tt", <<'...');
[% IF pager %]
    <div class="pagination">
        <ul>
            [% IF pager.previous_page %]
                <li class="prev"><a href="[% uri_with({page => pager.previous_page}) %]" rel="previous">&larr; Back</a><li>
            [% ELSE %]
                <li class="prev disabled"><a href="#">&larr; Back</a><li>
            [% END %]

            [% IF pager.can('pages_in_navigation') %]
                [% # IF Data::Page::Navigation is loaded %]
                [% FOR p IN pager.pages_in_navigation(5) %]
                    <li [% IF p==pager.current_page %]class="active"[% END %]><a href="[% uri_with({page => p}) %]">[% p %]</a></li>
                [% END %]
            [% ELSE %]
                <li><a href="#">[% pager.current_page %]</a></li>
            [% END %]

            [% IF pager.next_page %]
                <li class="next"><a href="[% uri_with({page => pager.next_page}) %]" rel="next">Next &rarr;</a><li>
            [% ELSE %]
                <li class="next disabled"><a href="#">Next &rarr;</a><li>
            [% END %]
        </ul>
    </div>
[% END %]
...
}

sub run {
    my $self = shift;

    $self->load_asset('jQuery');
    $self->load_asset('Bootstrap');
    $self->load_asset('ES5Shim');
    $self->load_asset('MicroTemplateJS');
    $self->load_asset('StrftimeJS');
    $self->load_asset('SprintfJS');

    Amon2::Setup::Flavor::Minimum::run($self);

    $self->write_static_files();

    $self->write_file('app.psgi', <<'...', {header => $self->psgi_header});
<% header %>
use <% $module %>::Web;
use <% $module %>;
use Plack::Session::Store::Redis;
use Plack::Session::State::Cookie;
use DBI;

{
    my $c = <% $module %>->new();
    $c->setup_schema();
}
my $session_config = <% $module %>->config->{session} || die "Missing configuration for session";
builder {
    enable 'Plack::Middleware::ReverseProxy';
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/robots\.txt|/favicon\.ico)$},
        root => File::Spec->catdir(dirname(__FILE__), 'static');
    enable 'Plack::Middleware::Session',
        store => Plack::Session::Store::Redis->new(
            %{$session_config},
        ),
        state => Plack::Session::State::Cookie->new(
            httponly => 1,
        );
    <% $module %>::Web->to_app();
};
...

    $self->write_file('lib/<<PATH>>.pm', <<'...');
package <% $module %>;
use strict;
use warnings;
use utf8;
use parent qw/Amon2/;
our $VERSION='0.01';
use 5.016_001;

# initialize database
use DBI;
sub setup_schema {
    my $self = shift;
    my $dbh = $self->dbh();
    my $driver_name = $dbh->{Driver}->{Name};
    my $fname = lc("sql/${driver_name}.sql");
    open my $fh, '<:encoding(UTF-8)', $fname or die "$fname: $!";
    my $source = do { local $/; <$fh> };
    for my $stmt (split /;/, $source) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr();
    }
}

1;
...

    $self->create_web_pms();

    $self->write_file('db/.gitignore', <<'...');
*
...

    for my $env (qw(development deployment test)) {
        my $module = $self->{module};
        my $db_basename = $module;
        $db_basename =~ s/::/_/;
        $db_basename = lc $db_basename;
        my $dbname = {
            development => "${db_basename}_dev",
            deployment  => $db_basename,
            test        => "${db_basename}_test",
        }->{$env};
        $self->write_file("config/${env}.pl", <<'...', {env => $env, dbname => $dbname});
use File::Spec;
use File::Basename qw(dirname);
my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
{
    'DBI' => [
        "dbi:mysql:dbname=<% $dbname %>;host=127.0.0.1",
        'root',
        '',
        {
            RaiseError => 1,
            mysql_enable_utf8 => 1,
            mysql_connect_timeout => 60,
        }
    ],
    Redis => {server => '127.0.0.1:6379'},
    session => {
        prefix => '<% $module %>_session_<% $env %>',
        host => '127.0.0.1',
        port => '6379',
        expires => 3600 * 24 * 7,
    },
};
...
    }

    $self->write_file("sql/mysql.sql", <<'...');
CREATE TABLE IF NOT EXISTS sessions (
    id           CHAR(72) PRIMARY KEY,
    session_data TEXT
);
...

    $self->write_file("t/00_compile.t", <<'...');
use strict;
use warnings;
use utf8;
use Test::More;

use_ok $_ for qw(
    <% $module %>
    <% $module %>::Web
    <% $module %>::Web::Dispatcher
);

done_testing;
...

    $self->write_file("xt/02_perlcritic.t", <<'...');
use strict;
use Test::More;
eval q{
    use Perl::Critic 1.113;
    use Test::Perl::Critic 1.02 -exclude => [
        'Subroutines::ProhibitSubroutinePrototypes',
        'Subroutines::ProhibitExplicitReturnUndef',
        'TestingAndDebugging::ProhibitNoStrict',
        'ControlStructures::ProhibitMutatingListFunctions',
    ];
};
plan skip_all => "Test::Perl::Critic 1.02+ and Perl::Critic 1.113+ is not installed." if $@;
all_critic_ok('lib');
...

    $self->write_file('.gitignore', <<'...');
Makefile
inc/
MANIFEST
*.bak
*.old
nytprof.out
nytprof/
*.db
blib/
pm_to_blib
META.json
META.yml
MYMETA.json
MYMETA.yml
...

    $self->write_file('t/03_assets.t', <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;

my $app = Plack::Util::load_psgi 'app.psgi';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        for my $fname (qw(static/bootstrap/bootstrap.css robots.txt)) {
            my $req = HTTP::Request->new(GET => "http://localhost/$fname");
            my $res = $cb->($req);
            is($res->code, 200, $fname) or diag $res->content;
        }
    };

done_testing;
...

    $self->write_file('.proverc', <<'...');
-l
-r t
-Mt::Util
...

    $self->write_file('t/06_jslint.t', <<'...');
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Requires 'Text::SimpleTable';

plan skip_all => 'this test requires "jsl" command'
  unless `jsl` =~ /JavaScript Lint/;

my @files = (<static/*/*.js>, <static/*/*/*.js>, <static/*/*/*/*.js>);
plan tests => 1 * @files;

my $table = Text::SimpleTable->new( 25, 5, 5 );

for my $file (@files) {
    # 0 error(s), 6 warning(s)
    my $out = `jsl -stdin < $file`;
    if ( $out =~ /((\d+) error\(s\), (\d+) warning\(s\))/ ) {
        my ( $msg, $err, $warn ) = ( $1, $2, $3 );
        $file =~ s!^static/[^/]+/!!;
        $table->row( $file, $err, $warn );
        is $err, 0, $file;
    }
    else {
        ok 0;
    }
}

note $table->draw;
...

    for my $status (qw/404 500 502 503 504/) {
        $self->write_status_file("static/$status.html", $status);
    }

    $self->write_file('lib/<<PATH>>/Model.pm', <<'...', {});
package <% $module %>::Model
use 5.016_001;
use warnings;

use <% $module %>::DB;
use <% $module %>;

sub db {
    my ($class, %args) = @_;
   
}


1;
...
}

sub create_web_pms {
    my ($self) = @_;

    $self->write_file('lib/<<PATH>>/Web.pm', <<'...', { xslate => $self->create_view() });
package <% $module %>::Web;
use strict;
use warnings;
use utf8;
use parent qw/<% $module %> Amon2::Web/;
use File::Spec;

# dispatcher
use <% $module %>::Web::Dispatcher;
sub dispatch {
    return (<% $module %>::Web::Dispatcher->dispatch($_[0]) or die "response is not generated");
}

<% $xslate %>

# load plugins
__PACKAGE__->load_plugins(
    'Web::FillInFormLite',
    'Web::CSRFDefender',
    'Web::JSON',
);

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;

        # http://blogs.msdn.com/b/ie/archive/2008/07/02/ie8-security-part-v-comprehensive-protection.aspx
        $res->header( 'X-Content-Type-Options' => 'nosniff' );

        # http://blog.mozilla.com/security/2010/09/08/x-frame-options/
        $res->header( 'X-Frame-Options' => 'DENY' );

        # Cache control.
        $res->header( 'Cache-Control' => 'private' );
    },
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my ( $c ) = @_;
        # ...
        return;
    },
);

1;
...

    $self->write_file("lib/<<PATH>>/Web/Dispatcher.pm", <<'...');
package <% $module %>::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::Lite;

any '/' => sub {
    my ($c) = @_;
    $c->render('index.tt');
};

post '/account/logout' => sub {
    my ($c) = @_;
    $c->session->expire();
    $c->redirect('/');
};

1;
...
}

sub create_makefile_pl {
    my ($self, $prereq_pm) = @_;

    $self->write_file('Build.PL', <<'...', {deps => $prereq_pm});
use strict;
use warnings;
use Module::Build;

my $buiild = Module::Build->new(
    dist_author => 'Nishibayashi Takuji <takuji31@gmail.com>',
    dist_abstract => '<% $dist %>',
    license     => 'perl',
    module_name => '<% $module %>',
    configure_requires => {'Module::Build' => '0.38'},
    requires => {
        'Amon2'                           => '<% $amon2_version %>',
        'DateTimeX::Factory'              => '0.03',
        'DBD::mysql'                      => '4.021',
        'DBI'                             => '1.622',
        'HTML::FillInForm::Lite'          => '1.09',
        'JSON'                            => '2.50',
        'Plack::Middleware::Session'      => '0',
        'Plack::Middleware::ReverseProxy' => '0.09',
        'Plack::Session::Store::Redis'    => '0.03',
        'Teng'                            => '0.15',
        'Text::Xslate'                    => '1.5017',
<% FOR v IN deps.keys() -%>
        <% sprintf("%-33s", "'" _ v _ "'") %> => '<% deps[v] %>',
<% END -%>
    },
    build_requires => {
        'Test::More'                 => '0.98',
        'Test::WWW::Mechanize::PSGI'      => 0,
    },
    test_files => (-d '.git/' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,

    create_readme => 1,
    create_license => 1,
    create_makefile_pl => 'small',
);
$buiild->create_build_script();
...
}

sub create_t_util_pm {
    my ($self, $export, $more) = @_;
    $export ||= [];
    $more ||= '';

    Amon2::Setup::Flavor::Minimum::create_t_util_pm($self, [@$export, qw(test_service)], $more . "\n" . <<'...');
sub slurp {
    my $fname = shift;
    open my $fh, '<:encoding(UTF-8)', $fname or die "$fname: $!";
    do { local $/; <$fh> };
}

sub test_service(&) {
    my $code = shift;
    setup_db();
    $code->(@_);
}

use <% $module %>;
sub setup_db {
    <% $module %>->bootstrap();
    my $c = Amon2->context;
    my $dsn = $c->config->{DBI}->[0];
    $dsn =~ /^dbi:mysql:dbname=([^;]+);?.*$/;
    my $dbname = $1;
    die "Database name not found" unless $dbname;
    my $db = $c->db;
    $db->do("DROP DATABASE $db IF EXISTS");
    $db->do("CREATE DATABASE $db DEFAULT CHARACTER SET utf8");
    $c->setup_schema();
}

# initialize database
setup_db();
...
}

1;
__END__
