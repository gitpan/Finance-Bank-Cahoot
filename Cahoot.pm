package Finance::Bank::Cahoot;
use strict;
use Carp;
our $VERSION = '1.01';
our $agent = WWW::Mechanize->new(cookie_jar => {});

use WWW::Mechanize;

sub check_balance {
    my ($class, %opts) = @_;
    my @accounts;
    croak "Must provide a username" unless exists $opts{username};
    croak "Must provide a password" unless exists $opts{password};
	croak "Must provide a memorable address" unless exists $opts{memorable_address};
	croak "Must provide a maiden name" unless exists $opts{maiden_name};
	croak "Must provide a memorable date" unless exists $opts{memorable_date};

    my $self = bless { %opts }, $class;
    
    $agent->get("http://www.cahoot.com/cahoot_products/cahoot_home_choices/cahoot_choices.html");

	$agent->follow_link(url_regex => qr/log_in/i);
	# navigate frames
	$agent->follow_link(url_regex => qr/Login/i);

	#  Filling in the login form. 
	my $form = $agent->form_number(1);
	my %fields = (inputuserid => $opts{username},inputpassword => $opts{password});
	if ($form->{inputs}[2]->name eq "inputmemorableAddress") {	
		$fields{inputmemorableAddress} = $opts{memorable_address};
	}
	elsif ($form->{inputs}[2]->name eq "inputmothersMaidenName") {
		$fields{inputmothersMaidenName} = $opts{maiden_name};
	}
	elsif ($form->{inputs}[2]->name eq "inputmemorableDate") {
		$fields{inputmemorableDate} = $opts{memorable_date};
	}
	$agent->set_fields(%fields);
	$agent->submit();	
	
	# navigate frames
	$agent->follow_link(url_regex => qr/homepage/i);
	$agent->follow_link(url_regex => qr/ViewHomePage/i);

    # Now we have the data, we need to parse it.  This is fragile.
    my $content = $agent->{content};
 
	while ($content =~ m!<tr>(.*?)</tr>!sgi) {
		my $accountname;
		my $currentbalance;
		my $availablebalance;
		my $accountnumber;
		my $accounttype;
		my $row = $1;
		while ($row =~ m!<td(.*?)>(.*?)</td>!sgi) {
			my $cellcontent = $2;
			my $cellattributes = $1;
			# check for accountname
			if ($cellattributes =~ /valign\W*=\W*"?top"?/i && $cellcontent =~ m!<b>(.*?)</b>.*?<a.*?productType=([A-Z]{1,3}).*?>(\d*)</a>!is && !$accountname) {
				$accountname = $1;
				$accounttype = $2;
				$accountnumber = $3;
				$accountname =~ s/:$//;
			}
			# check for current balance
			elsif ($accountname && $accountnumber && $cellcontent =~ /current\W*balance.*?(-?£?[0-9.]+)/si) {
				$currentbalance = $1;
				$currentbalance =~ s/£//g;
			}
			# check for available balance
			elsif ($accountname && $accountnumber && $cellcontent =~ /available\W*balance.*?(-?£?[0-9.]+)/si) {
				$availablebalance = $1;
				$availablebalance =~ s/£//g;
			}		
		}	
		if ($accountname && $accountnumber)	{
			push @accounts, (bless {
				available_balance	=> $availablebalance,
				current_balance		=> $currentbalance,
				name				=> $accountname,
				account				=> $accountnumber,
				account_type		=> $accounttype,
				parent				=> $self
			}, "Finance::Bank::Cahoot::Account");
		}
	}	
    return @accounts;
}

package Finance::Bank::Cahoot::Account;
use Carp;
no strict;
sub AUTOLOAD { my $self=shift; $AUTOLOAD =~ s/.*:://; $self->{$AUTOLOAD} }

sub statement {
    my $ac = shift;
	croak "No account type found!" unless $ac->account_type;
	croak "No account number found!" unless $ac->account;
	my @transactions;
	my $accountnum = sprintf("%010d",$ac->account);
    my $url = "/servlet/com.aquarius.accounts.servlet.PersonalHomepageSelectionServlet?productType=" . $ac->account_type ."&productId=$accountnum&origin=init";
    $Finance::Bank::Cahoot::agent->get($url);
	$Finance::Bank::Cahoot::agent->follow_link(url_regex => qr/$accountnum/i);
	
    # Now we have the data, we need to parse it.  This is fragile.
    my $content = $Finance::Bank::Cahoot::agent->{content};

	while ($content =~ m!<tr>(.*?)</tr>!sgi) {
		my $name;
		my $amount_credit;
		my $amount_debit;
		my $date;
		my $cellcount;
		my $row = $1;
		while ($row =~ m!<td(.*?)>(.*?)</td>!sgi) {
			my $cellcontent = $2;
			my $cellattributes = $1;
			# check for date
			if ($cellcontent =~ /([0-9]{2} [A-Za-z]{3} [0-9]{4})/) {
				$date = $1;
				$cellcount = 1;
			}
			#check for name
			elsif ($cellcount == 1)	{
				$name = $cellcontent;
				$cellcount++;
			}
			#check for debit
			elsif ($cellcount == 2)	{
				$cellcontent =~ s/[^0-9.]//g;
				$amount_debit = $cellcontent;
				$cellcount++;
			}
			#check for credit
			elsif ($cellcount == 3)	{
				$cellcontent =~ s/[^0-9.]//g;
				$amount_credit = $cellcontent;
				$cellcount++;
			}				
		}	
		if ($name && $date)	{
			push @transactions, {
				name			=> $name,
				amount_credit	=> $amount_credit,
				amount_debit	=> $amount_debit,
				date			=> $date
			};
		}
	}
    return @transactions;
}

1;
__END__

=head1 NAME

Finance::Bank::Cahoot - Check your Cahoot bank accounts from Perl

=head1 SYNOPSIS

  use Finance::Bank::Cahoot;
  my @accounts = Finance::Bank::Cahoot->check_balance(
      username => "xxxxxxxxxx",
      password   => "xxxxxx",
      memorable_address   => "xxxxxx",
      maiden_name   => "xxxxxx",
      memorable_date   => "xxxxxx"
  );

  foreach (@accounts) {
      printf "%25s : %18s : GBP %8.2f (%8.2f)\n",
        $_->{name}, $_->{account}, $_->{current_balance}, $_->{available_balance};
	  print "recent transactions: \n";
	  my @transactions = $_->statement;
	  foreach (@transactions) {
			printf "%25s : %14s : GBP -%8.2f +%8.2f\n",
			  $_->{name}, $_->{date}, $_->{amount_debit}, $_->{amount_credit};
	  }
  }

=head1 DESCRIPTION

This module provides a rudimentary interface to the Cahoot online
banking system at C<http://www.cahoot.com>. 

=head1 DEPENDENCIES

You will need either C<Crypt::SSLeay> or C<IO::Socket::SSL> installed 
for HTTPS support to work with LWP.  This module also depends on 
C<WWW::Mechanize> for screen-scraping.

=head1 CLASS METHODS

    check_balance( username => $u, password => $p, memorable_address => $a, maiden_name => $m, memorable_date => $d)

Return an array of account objects, one for each of your bank accounts.

=head1 ACCOUNT OBJECT METHODS

    $ac->name
    $ac->account
    $ac->account_type
    $ac->available_balance
    $ac->current_balance
 
Return the account name, account number, account type and available/current balances
as signed floating point values.

    $ac->statement

Return an array of hashes for the most recent transactions. (payee name, date, debit amount and credit amount)

=head1 TRANSACTION HASH KEYS

    $tr->name
    $tr->date
    $tr->amount_debit
    $tr->amount_credit

=head1 WARNING

This warning is from Simon Cozens' C<Finance::Bank::LloydsTSB>, and seems
just as apt here.

This is code for B<online banking>, and that means B<your money>, and
that means B<BE CAREFUL>. You are encouraged, nay, expected, to audit
the source of this module yourself to reassure yourself that I am not
doing anything untoward with your banking data. This software is useful
to me, but is provided under B<NO GUARANTEE>, explicit or implied.

=head1 NOTES

This has only been tested on my Cahoot accounts. This only represents a subset of the 
accounts available. They should all follow a consistent layout for the statement method
but this is not guaranteed to be the case.

=head1 THANKS

Chris Ball for C<Finance::Bank::HSBC>, Simon Cozens for C<Finance::Bank::LloydsTSB>,
Andy Lester (and Skud, by continuation) for WWW::Mechanize.

=head1 AUTHOR

Andy Kelk C<mopoke@cpan.org>

=cut


