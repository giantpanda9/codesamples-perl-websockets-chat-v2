#!/usr/bin/perl -w

use strict;
use warnings;
use Config::Simple;
use Net::WebSocket::Server;
use DBI;
use JSON qw(decode_json);
my $cfg = new Config::Simple('chat_config.cfg');

Net::WebSocket::Server->new(
    listen => $cfg->param('listen_port'),
    on_connect => sub {
        my ($serv, $conn) = @_;
        $conn->on(
            utf8 => sub {
                my ($conn, $msg) = @_;                        
                my ($srv, $chat_user, $user_msg) = @{decode_json($msg)}; #To solve the issue with inability to use : in user name
                $srv =~ s|<.+?>||g; #remove html tags to avoid bad code execution
                $chat_user =~ s/<.+?>//g; #remove html tags to avoid bad code execution 
                $user_msg =~ s/<.+?>//g; #remove html tags to avoid bad code execution 
                if ($srv eq "msg") {
                    if (length($chat_user) > 255) {
                        $msg = substr($chat_user,0,255); #Strip nickname to 255
                    }
                    if (length($user_msg) > 255) {
                        $msg = substr($user_msg,0,255); #Strip message to twit size
                    }
                    historyadd($chat_user, $user_msg);
                   
                    $_->send_utf8("$chat_user:$user_msg") for $conn->server->connections;
                } else {
                    $msg = gethistory();
                    $conn->send_utf8($msg);
                }
               
            },
        );
    },
)->start;


sub historyadd { 
    
    my $name=shift;
    my $msg=shift;
    
    my $conn_line = "DBI:Pg:dbname=" . $cfg->param('db_name') . ";host=" . $cfg->param('db_host');
    my $myConnection = DBI->connect($conn_line, $cfg->param('db_user'), $cfg->param('db_pass')) || die "Can not connect to the database " . DBI->errstr;
    
    my $query = $myConnection->prepare("INSERT INTO history (username,message) VALUES (?,?)");
    my $result = $query->execute($name, $msg) || die "Can not execute query " .  DBI->errstr;
    $query->finish();
    $myConnection->disconnect;
   
    return;
    
}

sub gethistory { 
    
    my $conn_line = "DBI:Pg:dbname=" . $cfg->param('db_name') . ";host=" . $cfg->param('db_host');
    my $myConnection = DBI->connect($conn_line, $cfg->param('db_user'), $cfg->param('db_pass')) || die "Can not connect to the database " .  DBI->errstr;
    my $query;
  
    $query = $myConnection->prepare("SELECT username,message FROM history WHERE date_created='NOW()'");
  
    my $result = $query->execute() || die "Can not execute query " .  DBI->errstr;
    if ($result != '0E0') {
        my $msg = "";
        while (my $item = $query->fetchrow_hashref) {
            $msg .=   $item->{username} . ":" . $item->{message} . "<br/>";            
        }
        return $msg;
    }
    $query->finish();
    $myConnection->disconnect;

    return;
    
}
