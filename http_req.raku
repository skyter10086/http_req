use v6.d;

use HTTP::UserAgent;
use HTTP::Header;
use HTTP::Request;
use URI;
use JSON::Fast;
use Text::CSV;

sub parse-headfile(Str $file_name --> HTTP::Request) {
    my $fh = open $file_name;
    unless $fh {
        put "Error: {$fh.exception}";
        exit;
    }
    my %headers;
    my $req_mtd;
    my $path;
    my $version;
    
    for $fh.lines() {
        if m/^(\w+)\:\s+(.+)$/ {
            my $k = $0.Str;
            my $v = $1.Str;
            %headers.{$k} = $v;
        } else {
            if m/(GET||POST)\s+(\S+)\s+(\S+)/ {
                $req_mtd = $0.Str;
                $path = $1.Str;
                $version = $2.Str;
            }
        }
    }
    my $url = 'http://' ~ %headers<Host> ~ $path;
    my $uri = URI.new($url);
    my $header = HTTP::Header.new(|%headers);
    my $req = HTTP::Request.new($req_mtd, $uri, $header);
    
    return $req;
}
my $ua = HTTP::UserAgent.new;
$ua.timeout = 10;

my $pre_req = parse-headfile('header.txt');

sub set-uri(HTTP::Request $req, Str $psn) {
    my $url = $req.url;
    my $pat = rx/personId\=/;
    $url ~~ m/$pat/;
    my $replace = $/.postmatch;
    $url ~~ s/$replace/$psn/;
    $req.uri($url);
    return $req;
}
#my $req = set-uri($pre_req,'41990081598026' );
sub get-json($req) {
    my $res = $ua.request($req);
    if $res.is-success {
        my $content = $res.content;
        my $x = from-json $content;
        my $obj = $x<bankUses>[0];
    
        my $sn = $obj<aaz010>;
        my $name = $obj<aic143>;
        my $id_card = $obj<aic145>;
        my $tel = $obj<aae005>;
        my $addr = $obj<aae006>;
        my $stat = $obj<bank><aae100>;
        my $acc_num = $obj<bank><aae010>;
        my $bank = $obj<bank><aaf200>;

        my $result = {
            sn => $sn,
            name => $name,
            id => $id_card,
            tel => $tel,
            address => $addr,
            stat => $stat,
            account => $acc_num,
            bank => $bank,
        };
        return $result;
    } else {
        die $res.status-line;
    }
}

sub put-json($req) {
        my $x = get-json($req);

        my $sn = $x<sn>;
        my $name = $x<name>;
        my $id_card = $x<id>;
        my $tel = $x<tel>;
        my $addr = $x<address>;
        my $stat = $x<stat>;
        my $acc_num = $x<account>;
        my $bank = $x<bank>;

        say "\n";
        say "****************************";
        say "sn:    $sn";
        say "name:    $name";
        say "id:    $id_card";
        say "tel:    $tel" if $tel;
        say "address:    $addr" if $addr;
        say "stat:    $stat";
        say "account:    $acc_num";
        say "bank:    $bank";
        say "****************************";
        say "\n";
}
sub read-paramfile(Str $file_name --> Array) {
    my $csv = Text::CSV.new;
    my $io = open $file_name, :r, chomp => False;
    unless $io {
        put "Error: {$io.exception}";
        exit;
    }
    my @psn = $csv.getline_all($io);
    my @p =  @psn.map: {$_[0]};

    return @p;
}

#`(
my @psn = read-paramfile('sn_3.csv');

for @psn {
    my $psn = $_[0];
    my $req = set-uri($pre_req, $psn);

    put-json($req);
}
)

sub out-csv(Str $headerfile, Str $paramfile, Str $outfile, Str $logfile) {
    my $pre_req = parse-headfile($headerfile);
    my @p = read-paramfile($paramfile);
    my $csv = Text::CSV.new;

    my $fh = open $outfile, :w
             or die $outfile.exception;

    my $log = open $logfile, :w
              or die $logfile.exception;
    
    my $i = 0;
    for @p {
        my $req = set-uri($pre_req, $_);
        my $x = get-json($req);
        my $row = [
            $x<sn>,
            $x<name>,
            $x<id>,
            $x<tel>,
            $x<address>,
            $x<stat>,
            $x<account>,
            $x<bank>,  
        ];

        $csv.say($fh, $row);
        ++$i;
        if $row {
            $log.say: "\[$i\]    $x<sn> 账户数据已写入文件。";
            say "\[$i\]    $x<sn> 账户数据已写入文件。";
        } else {
            $log.say: "\[$i\]    $x<sn> 账户数据已写入文件失败！";
            say "\[$i\]    $x<sn> 账户数据已写入文件失败！";
        }      
    }
    $fh.close;
    $log.close;
    
    $log.say: "数据写入完毕。";
    say "数据写入完毕。";

}

out-csv('header.txt','sn_3.csv', 'new.csv', 'log.txt');
