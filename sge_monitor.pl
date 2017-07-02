#!/usr/bin/perl

#***************************************************************************************************
# FileName: sge_monitor.pl
# Creator: Chen Y.L. <shenyulan@genomics.cn>
# Create Time: Sun Jul  2 19:18:53 CST 2017

# Description:
# CopyRight: 
# vision: 0.1
# ModifyList:
#   Revision: 
#   Modifier:
#   ModifyTime: 
#   ModifyReason: 
#***************************************************************************************************
use strict;
use warnings;
use File::Basename;


my $usage=<<usage;
    Usage: perl $0 <IN|job.sh>
    Example:
usage

die($usage) unless @ARGV >0;

my ($group) = @ARGV;
&group_monitor(2,$group);

sub group_monitor{
    my ($hibernation, $group) = @_;
    my %job_monitors;
    my $user_list = `grep '$group' /etc/group | awk -F':' '{print \$NF}' | xargs | tr ' ' ','`;
    my @users = (split /,/, $user_list);
    shift @users;

    reDo:
    {   
        my %jobs;
        my $stat;
        sleep $hibernation;
        my @storages = ("CLINIC", "DISEASE", "REHEAL", "STEMCELL");
        foreach my $disk (@storages){
            my ($total, $used, $avail, $use_p) = &get_storage("/hwfssz1/ST_MCHRI/$disk");
            print "$disk: $total, $used, $avail, $use_p\n";
        }

        map{
            $stat .= `qstat -u $_`;
        }(@users);

        foreach my $job (split /\n/, $stat){
            $job =~s/^\s+//g;
            next unless $job =~ /^\d+/;
            my ($job_ID, $prior, $name, $user, $state, $st_date, $st_time, $node) = (split /\s+/,$job);
            $jobs{$job_ID}{'state'} = $state;
            $jobs{$job_ID}{'node'} = '?';
            $jobs{$job_ID}{'node'} = $node if $state eq 'r';
        }

        map{
            my $log = "log";
            `qstat -j $_ > $log 2> /dev/null`;
            my ($job_number, $owner, $queue, $project, $script, $cwd, $num_proc, $virtual_free, $cpu, $vmem, $submission_time) = &parseQstat("$log");
            print "$job_number\t$jobs{$job_number}{'state'}\t$jobs{$job_number}{'node'}\t$owner\t$queue\t$project\t$num_proc\t$virtual_free\t$cpu\t$vmem\t$submission_time\t$script\t$cwd\n";
        }(keys %jobs);
    }
}

sub get_storage {
    my ($path) = @_;
    my $disk_space = `df -Th $path`;
    chomp $disk_space;
    my $info = (split /\n/, $disk_space)[-1];
    my ($total, $used, $avail, $use_p) = (split /\s+/, $info)[-5, -4, -3,-2];
    return ($total, $used, $avail, $use_p);
}

sub parseQstat {
    my ($log)= @_;
    my ($job_number, $submission_time, $num_proc, $virtual_free, $owner, $queue, $project, $script, $cwd)=('?','?', 1, '?','?','?','?', '?','?','?');
    my ($cpu, $mem, $io, $vmem, $maxvem) = ('?','?','?','?','?');
    my $now_time = `date`;
    chomp $now_time;
    open LOG, "$log" or die $!;
    while(<LOG>){
        chomp;
        $job_number = $1 if /job_number:\s+(\d+)/;
        $submission_time = $1 if /submission_time:\s+(.*)/;
        $owner = $1 if /owner:\s+(\S+)/;
        $queue = $1 if /hard_queue_list:\s+(\S+)/;
        $project = $1 if /project:\s+(\S+)/;
        $script = $1 if /script_file:\s+(\S+)/;
        $cwd = $1 if /cwd:\s+(\S+)/;
        if(/hard resource_list:\s+(\S+)/){
            my $resource = $1;
            map{$num_proc = $1 if /num_proc=(\S+)/; $virtual_free = $1 if /virtual_free=(\S+)/;}(split /,/, $resource);
        }
       ($cpu, $mem, $io, $vmem, $maxvem)= ($1, $2, $3, $4, $5) if /usage    1:\s+cpu=(\S+), mem=(.*), io=(\S+), vmem=(\S+), maxvmem=(\S+)/;
        last if /scheduling info/;
    }
    close LOG;
    return ($job_number, $owner, $queue, $project, $script, $cwd, $num_proc, $virtual_free, $cpu, $vmem, $submission_time);
}
