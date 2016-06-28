#!/usr/bin/perl -w

use strict;
use warnings;
use Encode;
use JSON::PP qw( decode_json );
use LWP::Simple;

binmode STDOUT, ":utf8";
$| = 1;

my ($rootfolderkey, $outtype, $outfile, $filename_length, $defaultsort);
my $fileh;

sub main {
    # Args
    process_args();
    
    # Defaults
    usage() unless($rootfolderkey);
    $outtype = 'text' unless($outtype);
    unless($outfile) {
        $outfile = 'denpa-dumper.txt' if($outtype eq 'text');
        $outfile = 'denpa-dumper.html' if($outtype eq 'html');
    }
    $filename_length = 80 unless($filename_length);
    $defaultsort = 'name' unless($defaultsort);
    
    # Start
    unless($outtype eq 'stdout') {
        print "Denpa Dumper v0.1\n";
        print "Writing to file $outfile\n";
        
        open($fileh, '>:utf8', $outfile);
    }
    
    out('<html><head><title>Mediafire link dump</title><meta http-equiv="Content-Type" content="text/html;charset=UTF-8"></head><body><pre>') if($outtype eq 'html');
    out("Denpa Dumper v0.1");
    
    # Load folder metadata
    my $start_time = time;
    my $folder_info = mediafire_info($rootfolderkey);
    my $folder_url;
    if($folder_info->{'custom_url'}) {
        $folder_url = 'http://mediafire.com/' .$folder_info->{'custom_url'};
    } else {
        $folder_url = 'http://mediafire.com/?' . $rootfolderkey;
    }
    
    unless($outtype eq 'stdout') {
        print "Folder: $folder_url (key: $rootfolderkey) sort by $defaultsort\n";
        print "Starting dump on " . format_time($start_time) . "\n";
    }
    
    out("Folder: $folder_url (key: $rootfolderkey) sort by $defaultsort");
    out("Starting dump on " . format_time($start_time));
    out('');
    
    out($folder_info->{'name'});
    dump_folder($rootfolderkey, 0);

    out('');
    out('Finished. Time taken: ' . (time - $start_time) . ' secs');
    out('</pre></body></html>') if($outtype eq 'html');
    
    unless($outtype eq 'stdout') {
        print('Finished. Time taken: ' . (time - $start_time) . ' secs' . "\n") unless($outtype eq 'stdout');
        close($fileh);
    }
}

sub process_args {
    my ($arg_out, $arg_type, $arg_length, $arg_sort);
    foreach my $arg (@ARGV) {
        if($arg_out) {
            die("Output file defined twice.") if($outfile);
            $outfile = $arg;
            $arg_out = 0;
        } elsif($arg_type) {
            die("Output type defined twice.") if($outtype);
            die("Invalid output type.") unless($arg =~ /^(stdout|text|html)$/);
            $outtype = $arg;
            $arg_type = 0;
        } elsif($arg_length) {
            die("Filename length defined twice.") if($filename_length);
            $filename_length = int($arg);
            $arg_type = 0;
        } elsif($arg_sort) {
            die("Sort defined twice.") if($defaultsort);
            die("Invalid sort.") unless($arg =~ /^(name|created|size|downloads)$/);
            $defaultsort = $arg;
            $arg_sort = 0;
        } elsif($arg eq '-h') {
            usage();
        } elsif($arg eq '-o') {
            $arg_out = 1;
        } elsif($arg eq '-t') {
            $arg_type = 1;
        } elsif($arg eq '-l') {
            $arg_length = 1;
        } elsif($arg eq '-s') {
            $arg_sort = 1;
        } elsif($arg =~ /^-(.+)/) {
            die("Unrecognized option: $_");
        } else {
            die("Folder key defined twice.") if($rootfolderkey);
            $rootfolderkey = $arg;
        }
    }
}

sub usage {
    print "denpa-dumper v0.1\n\n";
    print "USAGE:\n";
    print "  $0 [-h] [-o <outfile>] [-t <type>] [-l <length>] [-s <sort] <FOLDER KEY>\n\n";
    print "OPTIONS\n";
    print "  -h                Shows this help\n";
    print "  -o <outfile>      Filename of the output file\n";
    print "  -t <type>         Type of output, possible values: stdout, text, html\n";
    print "  -l <length>       Length to truncate the filename of a file (not used in HTML)\n";
    print "  -s <sort>         File sort type, possible values: name, created, size, downloads\n\n";
    exit(-1);
}

sub mediafire_info {
    my $folderkey = shift;
    
    my $response = get("http://www.mediafire.com/api/folder/get_info.php?folder_key=$folderkey&response_format=json");
    die "Error getting data from Mediafire API." unless defined $response;
    
    my $decoded = decode_json($response);
    return $decoded->{'response'}{'folder_info'};
}
sub mediafire_get {
    my ($action, $folderkey, $order) = @_;
    my $response = get("http://www.mediafire.com/api/folder/get_content.php?folder_key=$folderkey&content_type=$action&response_format=json&order_by=$order");
    die "Error getting data from Mediafire API." unless defined $response;
    
    my $decoded = decode_json($response);
    return @{$decoded->{'response'}{'folder_content'}{$action}};
}

sub gen_link {
    my $file = shift;
    if($outtype eq 'html') {
        return '<a href="http://mediafire.com/?'.$file->{'quickkey'}.'">'.$file->{'filename'}.'</a>';
    } else {
        return pack("A$filename_length",$file->{'filename'}).'  http://mediafire.com/?' .$file->{'quickkey'};
    }
}

sub dump_folder {
    my ($folderkey, $rec) = @_;
    my @folders = mediafire_get('folders', $folderkey, 'name');
    
    foreach my $folder (@folders) {
        print "Dumping folder " . $folder->{'name'} . "\n" unless($outtype eq 'stdout');
        out("|   "x$rec . "|-- " . $folder->{'name'});
        dump_folder($folder->{'folderkey'}, $rec+1);
    }
        
    my @files = mediafire_get('files', $folderkey, $defaultsort);
    foreach my $file (@files) {
        out("|   "x$rec ."|-- " . gen_link($file));
    }   
}

sub format_time {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(shift);
    $year = $year + 1900;
    $mon += 1;
    return "$mday/$mon/$year $hour:$min:$sec";
}

sub out {
    if($outtype eq 'stdout') {
        print shift."\n";
    } else {
        print $fileh shift."\n";
    }
}

main();
