#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use Test::More tests => 19;
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
	    'got expected account summary (list)' );

  ok($c->set_account($accounts[1]->{account}),
     'set account for account 1');
  $cs->clear;
  $c->set_account($accounts[1]->{account});
  is($cs->called('get'), 0, 'set account for same acount ignored');

  $cs->clear;
  $c->set_account($accounts[0]->{account});
  is($cs->called('get'), 1, 'set new account');

  {
    my $statement = $c->statement();
    is_deeply($statement,
	      [
	       [ '15 Oct 2007', 'ACME PHONE CORP BILLING', '13.02', '', '672.19'
	       ],
	       [ '16 Oct 2007', 'LEC CO ELECTRICITY', '15.55', '', '656.64'
	       ],
	       [ '22 Oct 2007', 'MAMMA ITALINA EUR 140.00', '100.08', '', '556.56'
	       ],
	       [ '22 Oct 2007', 'SERVICE CHARGE DEBIT', '1.40', '', '555.16'
	       ],
	       [ '31 Oct 2007', 'BIGGINS IT CONSULTANTS', '', '1827.26', '2382.42'
	       ]
	      ],
	      'extracted latest statement');
  }
  foreach my $method (qw(account password place date username maiden)) {
    no strict 'refs';
    undef *{"Finance::Bank::Cahoot::CredentialsProvider::Constant::$method"};
  }
}

{
  my $c = Finance::Bank::Cahoot->new(credentials => 'Constant',
				     credentials_options => { account => '12345678',
							      password => 'verysecret',
							      place => 'London',
							      date => '01/01/1906',
							      username => 'dummy',
							      maiden => 'Smith' });
  dies_ok {
    $c->set_statement()
  } 'select undef statement: expected to fail';
  like($@, qr/No statement selected for set_statement/, 'exception: no statement selected');
  dies_ok {
    $c->set_statement('16/03/07 - 15/04/07')
  } 'select statement with no account: expected to fail';
  like($@, qr/No account currently selected/, 'exception: no account selected');
  dies_ok {
    $c->statements()
  } 'get statement with no account: expected to fail';
  like($@, qr/No account currently selected/, 'exception: no account selected');
  foreach my $method (qw(account password place date username maiden)) {
    no strict 'refs';
    undef *{"Finance::Bank::Cahoot::CredentialsProvider::Constant::$method"};
  }
}

{
  my $creds = Finance::Bank::Cahoot::CredentialsProvider::Constant->new(credentials => [qw(account password place date username maiden)],
									options => { account => '12345678',
										     password => 'verysecret',
										     place => 'London',
										     date => '01/01/1906',
										     username => 'dummy',
										     maiden => 'Smith' });

  my $c = Finance::Bank::Cahoot->new(credentials => $creds);
  my @accounts = $c->accounts();
  $c->set_account($accounts[0]->{account});
  my $statements = $c->statements;
  is_deeply($statements,
	    [
	     { 'description' => '16/09/07 - 15/10/07',
	       'end' => 1444172400,
	       'start' => 1473202800 },
	     { 'description' => '16/08/07 - 15/09/07',
	       'end' => 1441580400,
	       'start' => 1470524400 },
	     { 'description' => '16/07/07 - 15/08/07',
	       'end' => 1438902000,
	       'start' => 1467846000 },
	     { 'description' => '16/06/07 - 15/07/07',
	       'end' => 1436223600,
	       'start' => 1465254000 },
	     { 'description' => '16/05/07 - 15/06/07',
	       'end' => 1433631600,
	       'start' => 1462575600 },
	     { 'description' => '16/04/07 - 15/05/07',
	       'end' => 1430953200,
	       'start' => 1459983600 },
	     { 'description' => '16/03/07 - 15/04/07',
	       'end' => 1428361200,
	       'start' => 1457308800 },
	     { 'description' => '16/02/07 - 15/03/07',
	       'end' => 1425686400,
	       'start' => 1454803200 },
	     { 'description' => '16/01/07 - 15/02/07',
	       'end' => 1423267200,
	       'start' => 1452124800 },
	     { 'description' => '16/12/06 - 15/01/07',
	       'end' => 1420588800,
	       'start' => 1480982400 },
	     { 'description' => '16/11/06 - 15/12/06',
	       'end' => 1449360000,
	       'start' => 1478390400 },
	    ],
	    'got list of all statements');

  dies_ok {
    $c->set_statement('junk'),
  } 'invalid statement selected, expected to fail';
  like($@, qr/Invalid statement: junk/, 'exception: invalid statement');

  ok($c->set_statement($statements->[3]->{description}),
     'selected 4th statement in list');

  my $statement = $c->statement();
  is_deeply($statement,
	    [
	     [ '15 Oct 2007', 'ACME PHONE CORP BILLING', '13.02', '', '672.19'
	     ],
	     [ '16 Oct 2007', 'LEC CO ELECTRICITY', '15.55', '', '656.64'
	     ],
	     [ '22 Oct 2007', 'MAMMA ITALINA EUR 140.00', '100.08', '', '556.56'
	     ],
	     [ '22 Oct 2007', 'SERVICE CHARGE DEBIT', '1.40', '', '555.16'
	     ],
	     [ '31 Oct 2007', 'BIGGINS IT CONSULTANTS', '', '1827.26', '2382.42'
	     ]
	    ],
	   'extracted another statement');
}
