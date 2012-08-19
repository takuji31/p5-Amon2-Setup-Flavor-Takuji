use strict;
use Test::LoadAllModules;
use Test::More;

BEGIN {
    all_uses_ok(
        search_path => "Amon2::Setup::Flavor::Takuji",
        except => [],
    );
}


diag "Testing Amon2::Setup::Flavor::Takuji/$Amon2::Setup::Flavor::Takuji::VERSION";
