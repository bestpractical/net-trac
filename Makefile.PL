use warnings;
use strict;
use inc::Module::Install;

name        'Net-Trac';
all_from    'lib/Net/Trac.pm';
requires 'Moose';
requires 'URI';
requires 'IO::Scalar';
requires    'XML::Feed';
requires 'Text::CSV_XS';
requires 'LWP::Simple';

requires 'Params::Validate';

auto_install;
sign; 
WriteAll;
