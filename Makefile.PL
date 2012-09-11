#!/usr/bin/env perl
use inc::Module::Install;

name 'Test-WWW-Selenium-Mechanize';
all_from 'lib/Test/WWW/Selenium/Mechanize.pm';

requires 'Moose';
requires 'Parse::Selenese';
requires 'Test::More';
requires 'Test::WWW::Mechanize';
requires 'HTML::Strip';
requires 'HTML::TreeBuilder';
requires 'HTML::TreeBuilder::XPath';
requires 'HTML::Selector::XPath';
requires 'Data::Dump';

test_requires 'HTTP::Server::Simple::CGI';
test_requires 'Test::MockModule';
test_requires 'ok';


install_script glob('script/*');
WriteAll;
