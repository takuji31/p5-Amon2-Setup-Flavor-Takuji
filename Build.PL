use strict;
use warnings;
use Module::Build;

my $buiild = Module::Build->new(
    dist_author => 'Nishibayashi Takuji <takuji31@gmail.com>',
    dist_abstract => 'Amon2-Setup-Flavor-Takuji',
    license     => 'perl',
    module_name => 'Amon2::Setup::Flavor::Takuji',
    configure_requires => {'Module::Build' => '0.38'},
    requires => {
        'Amon2' => '3.52',
        'Exporter::Lite' => '0',
    },
    build_requires => {
        'Test::LoadAllModules'       => '0.021',
        'Test::More'                 => '0.98',
    },
    test_files => (-d '.git/' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,

    create_readme => 1,
    create_license => 1,
    create_makefile_pl => 'small',
);
$buiild->create_build_script();
