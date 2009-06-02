use inc::Module::Install;
name 'Net-GitHub-Upload';
all_from 'lib/Net/GitHub/Upload.pm';

test_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
