#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use Test::More tests => 6;
use Test::Exception;

use Mock::CahootWebServer;
my $cs = new Mock::CahootWebServer;

use_ok('Finance::Bank::Cahoot');
use_ok('Finance::Bank::Cahoot::CredentialsProvider::Constant');

{
  my $creds = Finance::Bank::Cahoot::CredentialsProvider::Constant->new(credentials => [qw(account password place date username maiden)],
									options => { account => '12345678',
										     password => 'verysecret',
										     place => 'London',
										     date => '01/01/1906',
										     username => 'dummy',
										     maiden => 'Smith' });

  ok(my $c = Finance::Bank::Cahoot->new(credentials => $creds),
     'valid credentials - providing premade credentials object');

  $c->login();
  my @accounts = $c->accounts();
  is_deeply(\@accounts,
	    [ { name => 'current account', account => '12345678',
		balance => '847.83', available => '1847.83' },
	      { name => 'flexible loan', account => '87654321',
		balance => '0.00', available => '1000.00' },
	    ],
	    'Got expected account summary (list)' );

  ok($c->set_account($accounts[0]->{account}),
     'set account for account 0');

  {
    my $statement = $c->snapshot();
    is_deeply($statement,
	      [
	       [ '22 Nov 2007', 'BIGGINS IT CONSULTANTS', '1827.26', ''
	       ],
	       [ '23 Nov 2007', 'GIVESALOT CHARITY CREDIT CARD', '938.65', ''
	       ],
	       [ '01 Dec 2007', 'TAX ON CR INTEREST', '2.25', ''
	       ],
	       [ '01 Dec 2007', 'INTEREST PAID', '', '11.23'
	       ],
	       [ '08 Dec 2007', 'LEC CO ELECTRICITY', '34.12', ''
	       ],
	       [ '08 Dec 2007', 'GASCO LIMITED', '37.11', ''
	       ],
	       [ '10 Dec 2007', 'MAIN STREET ATM', '50.00', ''
	       ],
	       [ '11 Dec 2007', 'ACME PHONE CORP BILLING', '18.72', ''
	       ],
	       [ '15 Dec 2007', 'JON DOE', '', '15.00'
	       ],
	       [ '15 Dec 2007', 'MARK SMITH', '', '14.45'
	       ]
	      ], 'got statement');
  }
}
