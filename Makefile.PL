use inc::Module::Install;
name 'Net-GitHub-Upload';
all_from 'lib/Net/GitHub/Upload.pm';

requires 'URI';
requires 'LWP::UserAgent';
requires 'Web::Scraper';
requires 'Path::Class';
requires 'JSON';
requires 'Pod::Usage';
requires 'Crypt::SSLeay';

install_script 'scripts/github-upload';

test_requires 'Test::More';
use_test_base;
author_tests 'xt';

auto_include;
WriteAll;
