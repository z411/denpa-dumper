use strict;
use warnings;
use JSON qw( decode_json );
use LWP::Simple;

binmode STDOUT, ":utf8";

my $rootfolderkey = 'xczuuk44mz3hv';
my $br = "\n";

sub mediafire_get($$$) {
    my ($action, $folderkey, $order) = @_;
    my $response = get("http://www.mediafire.com/api/folder/get_content.php?folder_key=$folderkey&content_type=$action&response_format=json&order_by=$order");
    die "Error getting data from Mediafire API." unless defined $response;
    
    my $decoded = decode_json($response);
    return @{$decoded->{'response'}{'folder_content'}{$action}};
}

sub gen_link($) {
    my $file = shift;
    return '<a href="http://mediafire.com/?'.$file->{'quickkey'}.'">'.$file->{'filename'}.'</a>';
}

sub format_time($) {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(shift);
    $year = $year + 1900;
    $mon += 1;
    return "$mday/$mon/$year $hour:$min:$sec";
}
my $start_time = time;
print '<html><head><title>Mediafire link dump</title><meta http-equiv="Content-Type" content="text/html;charset=UTF-8"></head><body><pre>';
print "Denpa Dumper v0.1" . $br;
print "Folder: (key: $rootfolderkey)" . $br;
print "Starting dump on " . format_time($start_time) . $br;
print $br;

print "Denpa / 電波ソング" . $br;
my @folders = mediafire_get('folders', $rootfolderkey, 'name');
foreach my $folder (@folders) {
    my $folderkey = $folder->{'folderkey'};
    print "|-- " . $folder->{'name'} . $br;
    
    if($folder->{'name'} eq 'Comiket') {
        my @cfolders = mediafire_get('folders', $folderkey, 'name');
        foreach my $cfolder (@cfolders) {
            my $cfolderkey = $cfolder->{'folderkey'};
            print "|   |-- " . $cfolder->{'name'} . $br;
            
            my @infiles = mediafire_get('files', $cfolderkey, 'created');
            foreach my $infile (@infiles) {
                print "|   |   |-- " . gen_link($infile) . $br;
            }  
        }
    }
    
    my @files = mediafire_get('files', $folderkey, 'created');
    foreach my $file (@files) {
        print "|   |-- " . gen_link($file) . $br;
    }   
}

my @files = mediafire_get('files', $rootfolderkey, 'created');
foreach my $file (@files) {
    print "|-- " . gen_link($file) . $br;
}
print $br;
print 'Finished. Time taken: ' . (time - $start_time) . ' secs';
print '</pre></body></html>';
