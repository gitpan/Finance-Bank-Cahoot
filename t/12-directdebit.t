#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use Test::More tests => 9;
use Test::Exception;
use Test::Deep;

use Mock::CahootWebServer;
my $cs = new Mock::CahootWebServer;

use_ok('Finance::Bank::Cahoot');
use_ok('Finance::Bank::Cahoot::CredentialsProvider::Constant');

{
  dies_ok {
    my $row = Finance::Bank::Cahoot::DirectDebit->new;
  } 'no data row to constructor: expected to fail';
  like($@, qr/No row data passed to Finance::Bank::Cahoot::DirectDebit constructor at /,
       'exception: no data row to constructor');

  dies_ok {
    my $row = Finance::Bank::Cahoot::DirectDebit->new('bogus')
  } 'invalid data row to constructor: expected to fail';
  like($@, qr/row data is not an array ref at /,
       'exception: invalid data row to constructor');
}

{
  my $creds = Finance::Bank::Cahoot::CredentialsProvider::Constant->new(
        credentials => [qw(account password place date username maiden)],
        options => { account => '12345678',
                     password => 'verysecret',
                     place => 'London',
                     date => '01/01/1906',
                     username => 'dummy',
                     maiden => 'Smith' });

  ok(my $c = Finance::Bank::Cahoot->new(credentials => $creds),
     'valid credentials - providing premade credentials object');

  $c->login();
  my $accounts = $c->accounts();
  $c->set_account($accounts->[0]->{account});
  my $debits = $c->debits();
  cmp_deeply($debits,
             array_each(isa('Finance::Bank::Cahoot::DirectDebit')),
             'got an array of direct debits');
  cmp_deeply($debits,
             [ methods(payee => 'ACME WATER CO',
                       reference => '07028928282',
                       amount => '20.14',
                       date => '01-Sep-2008',
                       frequency => 'Every 0'),
               methods(payee => 'HAPPYSHIRE COUNCIL',
                       reference => '282726272',
                       amount => '200.00',
                       date => '15-Sep-2008',
                       frequency => 'Every 0'),
               methods(payee => 'TV LICENCE',
                       reference => '06904826736',
                       amount => '11.95',
                       date => '01-Sep-2008',
                       frequency => 'Every 0'),
               methods(payee => 'LOOPY CAR INSURE',
                       reference => '9762041',
                       amount => '282.00',
                       date => '01-Apr-2008',
                       frequency => 'Every 0'),
               methods(payee => 'LECCO GAS CO',
                       reference => '337710',
                       amount => '17.00',
                       date => '01-Aug-2008',
                       frequency => 'Every 0'),
               methods(payee => 'BONGO.COM SUBSCRIPTION',
                       reference => '7227REFVD',
                       amount =>'22.00',
                       date => '01-Sep-2008',
                       frequency => 'Every 0'),
               methods(payee => 'LINUX FOOBARS MAGAZINE',
                       reference => 'SCAMMING101',
                       amount =>'37.00',
                       date => '03-Dec-2007',
                       frequency => 'Every 0'),
               methods(payee => 'ROBBERS HOUSE INSURANCE',
                       reference => '29272635647262',
                       amount =>'2827.13',
                       date => '01-Mar-2008',
                       frequency => 'Every 0'),
               methods(payee => 'NORWICH UNION',
                       reference => '28272718HDUYST',
                       amount =>'10.99',
                       date => '01-Sep-2008',
                       frequency => 'Every 0'),
               methods(payee => 'ACME DIRECT DEBITS',
                       reference => '2928272762',
                       amount =>'117.28',
                       date => '23-Sep-2008',
                       frequency => 'Every 0') ],
             'got expected list of direct debits');
}
