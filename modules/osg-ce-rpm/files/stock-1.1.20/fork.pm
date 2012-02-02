# Globus::GRAM::JobManager::fork package

use Globus::GRAM::Error;
use Globus::GRAM::JobState;
use Globus::GRAM::JobManager;
use Globus::GRAM::StdioMerger;
use Globus::Core::Paths;

use Config;
use IPC::Open2;

# NOTE: This package name must match the name of the .pm file!!
package Globus::GRAM::JobManager::fork;

@ISA = qw(Globus::GRAM::JobManager);

my ($mpirun, $mpiexec);
my %signo;

BEGIN
{
    my $i = 0;

    foreach (split(' ', $Config::Config{sig_name})) 
    {
        $signo{$_} = $i++;
    }

    $mpirun         = 'no';
    $mpiexec        = 'no';
    $softenv_dir    = '';
    $soft_msc       = "$softenv_dir/bin/soft-msc";
    $softenv_load   = "$softenv_dir/etc/softenv-load.sh";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my $description = $self->{JobDescription};
    my $stdout = $description->stdout();
    my $stderr = $description->stderr();

    if($description->jobtype() eq 'multiple' && $description->count > 1)
    {
        $self->{STDIO_MERGER} =
            new Globus::GRAM::StdioMerger($self->job_dir(), $stdout, $stderr);
    }
    else
    {
        $self->{STDIO_MERGER} = 0;
    }

    return $self;
}

sub submit
{
    my $self = shift;
    my $cmd;
    my $pid;
    my $pgid;
    my @job_id;
    my $count;
    my $multi_output = 0;
    my $description = $self->{JobDescription};
    my $pipe;
    my @cmdline;
    my @environment;
    my @library_path;
    my @arguments;
    my $fork_starter = "$ENV{GLOBUS_LOCATION}/libexec/globus-fork-starter";
    my $fork_conf = "$ENV{GLOBUS_LOCATION}/etc/globus-fork.conf";
    my $log_path = '/dev/null';
    my $is_grid_monitor = 0;

    if (-r $fork_conf)
    {
        local(*IN);

        open(IN, "<$fork_conf");

        while (<IN>) {
            if (m/log_path=(.*)$/) {
                $log_path = $1;
            }
        }

        close(IN);
    }

    if(!defined($description->directory()))
    {
        return Globus::GRAM::Error::RSL_DIRECTORY;
    }
    if ($description->directory() =~ m|^[^/]|) {
        $description->add("directory",
                $ENV{HOME} . '/' . $description->directory());
    }
    chdir $description->directory() or
        return Globus::GRAM::Error::BAD_DIRECTORY;

    @environment = $description->environment();
    foreach $tuple ($description->environment())
    {
        if(!ref($tuple) || scalar(@$tuple) != 2)
        {
            return Globus::GRAM::Error::RSL_ENVIRONMENT();
        }
        $CHILD_ENV{$tuple->[0]} = $tuple->[1];
    }

    @library_path = $description->library_path();

    foreach (@library_path)
    {
        if(ref($_))
        {
            $self->log("Invalid library_path value");
            return Globus::GRAM::Error::RSL_ENVIRONMENT();
        }
        $self->append_path(\%CHILD_ENV, 'LD_LIBRARY_PATH', $_);
        if($Config::Config{osname} eq 'irix')
        {
            $self->append_path(\%CHILD_ENV, 'LD_LIBRARYN32_PATH', $_);
            $self->append_path(\%CHILD_ENV, 'LD_LIBRARY64_PATH', $_);
        }
    }

    $self->append_path(\%CHILD_ENV, 'LD_LIBRARY_PATH', $ENV{LD_LIBRARY_PATH});
    $self->append_path(\%CHILD_ENV, 'PERL5LIB', $ENV{PERL5LIB});
    $self->append_path(\%CHILD_ENV, 'PATH', $ENV{PATH});

    if(ref($description->count()) ||
       $description->count() != int($description->count()))
    {
        return Globus::GRAM::Error::INVALID_COUNT();
    }
    if($description->jobtype() eq 'multiple')
    {
        $count = $description->count();
        $multi_output = 1 if $count > 1;
    }
    elsif($description->jobtype() eq 'single')
    {
        $count = 1;
    }
    elsif($description->jobtype() eq 'mpi' && $mpiexec ne 'no')
    {
        $count = 1;
        @cmdline = ($mpiexec, '-n', $description->count());
    }
    elsif($description->jobtype() eq 'mpi' && $mpirun ne 'no')
    {
        $count = 1;
        @cmdline = ($mpirun, '-np', $description->count());
    }
    else
    {
        return Globus::GRAM::Error::JOBTYPE_NOT_SUPPORTED();
    }
    if( $description->executable eq "")
    {
        return Globus::GRAM::Error::RSL_EXECUTABLE();
    }
    elsif(! -e $description->executable())
    {
        return Globus::GRAM::Error::EXECUTABLE_NOT_FOUND();
    }
    elsif( (! -x $description->executable())
        || (! -f $description->executable()))
    {
        return Globus::GRAM::Error::EXECUTABLE_PERMISSIONS();
    }
    elsif( $description->stdin() eq "")
    {
        return Globus::GRAM::Error::RSL_STDIN;
    }
    elsif(! -r $description->stdin())
    {
        return Globus::GRAM::Error::STDIN_NOT_FOUND();
    }

    if ($description->executable() =~ m:^(/|\.):) {
        push(@cmdline, $description->executable());
    } else {
        push(@cmdline,
                $description->directory()
                . '/'
                . $description->executable());
    }

    # Check if this is the Condor-G grid monitor
    my $exec = $description->executable();
    my $file_out = `/usr/bin/file $exec`;
    if ( $file_out =~ /script/ || $file_out =~ /text/ ||
	 $file_out =~ m|/usr/bin/env| ) {
	open( EXEC, "<$exec" ) or
	    return Globus::GRAM::Error::EXECUTABLE_PERMISSIONS();
	while( <EXEC> ) {
	    if ( /Sends results from the grid_manager_monitor_agent back to a/ ) {
		$is_grid_monitor = 1;
	    }
	}
	close( EXEC );
    }

    # Reject jobs that want streaming, if so configured, but not for
    # grid monitor jobs
    if ( $description->streamingrequested() &&
	 $description->streamingdisabled() && !$is_grid_monitor ) {

	$self->log("Streaming is not allowed.");
	return Globus::GRAM::Error::OPENING_STDOUT;
    }

    @arguments = $description->arguments();
    foreach(@arguments)
    {
        if(ref($_))
        {
            return Globus::GRAM::Error::RSL_ARGUMENTS;
        }
    }
    if ($#arguments >= 0)
    {
        push(@cmdline, @arguments);
    }

    if ($description->use_fork_starter() && -x $fork_starter)
    {
        local(*STARTER_OUT, *STARTER_IN);

        $pid = IPC::Open2::open2(\*STARTER_OUT, \*STARTER_IN,
                "$fork_starter $log_path");
        my $oldfh = select STARTER_OUT;
        $|=1;
        select $oldfh;

        print STARTER_IN "100;perl-fork-start-$$;";
        
        print STARTER_IN 'directory='.
            &escape_for_starter($description->directory()) . ';';

        if (keys %CHILD_ENV > 0) {
            print STARTER_IN 'environment='.
                join(',', map { &escape_for_starter($_)
                        .'='.&escape_for_starter($CHILD_ENV{$_})
                    } (keys %CHILD_ENV)) . ';';
        }

        print STARTER_IN "count=$count;";

        my @softenv = $description->softenv();
        my $enable_default_software_environment
            = $description->enable_default_software_environment();
        if (   ($softenv_dir ne '')
            && (@softenv || $enable_default_software_environment))
        {
            ### SoftEnv extension ###
            $cmd_script_name = $self->job_dir() . '/scheduler_fork_cmd_script';
            local(*CMD);
            open( CMD, '>' . $cmd_script_name );

            print CMD "#!/bin/sh\n";

            $self->setup_softenv(
                $self->job_dir() . '/fork_softenv_cmd_script',
                $soft_msc,
                $softenv_load,
                *CMD);

            print CMD 'cd ', $description->directory(), "\n";
            print CMD "@cmdline\n";
            close(CMD);
            chmod 0700, $cmd_script_name;

            print STARTER_IN 'executable=' .
                &escape_for_starter($cmd_script_name). ';';
            print STARTER_IN 'arguments=;';
            #########################
        }
        else
        {
            print STARTER_IN 'executable=' .
                    &escape_for_starter($cmdline[0]). ';';
            shift @cmdline;
            if ($#cmdline >= 0)
            {
                print STARTER_IN 'arguments=' .
                        join(',', map {&escape_for_starter($_)} @cmdline) .
                        ';';
            }
        }
        
        my @job_stdout;
        my @job_stderr;

        for ($i = 0; $i < $count; $i++) {
            if($multi_output)
            {
                push(@job_stdout, $self->{STDIO_MERGER}->add_file('out'));
                push(@job_stderr, $self->{STDIO_MERGER}->add_file('err'));
            }
            else
            {
                if (defined($description->stdout)) {
                    push(@job_stdout, $description->stdout());
                } else {
                    push(@job_stdout, '/dev/null');
                }

                if (defined($description->stderr)) {
                    push(@job_stderr, $description->stderr());
                } else {
                    push(@job_stderr, '/dev/null');
                }
            }
        }

        print STARTER_IN "stdin=" . &escape_for_starter($description->stdin()).
                ';';
        print STARTER_IN "stdout=" .
                join(',', map {&escape_for_starter($_)} @job_stdout) . ';';
        print STARTER_IN "stderr=" .
                join(',', map {&escape_for_starter($_)} @job_stderr) . "\n";

        close(STARTER_IN);
        while (<STARTER_OUT>) {
            chomp;
            my @res = split(/;/, $_);

            if ($res[1] ne "perl-fork-start-$$") {
                next;
            }
            if ($res[0] == '101') {
                @job_id = split(',', $res[2]);
                last;
            } elsif ($res[0] == '102') {
                $self->respond({GT3_FAILURE_MESSAGE => "starter: $res[3]" });
                close(STARTER_OUT);
                return new Globus::GRAM::Error($res[2]);
            }
        }
        close(STARTER_OUT);
    } else {
        for(my $i = 0; $i < $count; $i++)
        {
            if($multi_output)
            {
                $job_stdout = $self->{STDIO_MERGER}->add_file('out');
                $job_stderr = $self->{STDIO_MERGER}->add_file('err');
            }
            else
            {
                $job_stdout = $description->stdout();
                $job_stderr = $description->stderr();
            }

            # obtain plain old pipe into temporary variables
            local $^F = 2;                # assure close-on-exec for pipe FDs
            local(*READER,*WRITER);        # always use local on perl FDs
            pipe( READER, WRITER );

            select((select(WRITER),$|=1)[$[]);

            if( ($pid=fork()) == 0)
            {
                close(READER);

                # forked child
                %ENV = %CHILD_ENV;

                close(STDIN);
                close(STDOUT);
                close(STDERR);

                open(STDIN, '<' . $description->stdin());
                open(STDOUT, ">>$job_stdout");
                open(STDERR, ">>$job_stderr");
                
                # the below should never fail since we just forked
                setpgrp(0,$$);

                if ( ! exec (@cmdline) )
                {
                    my $err = "$!\n";
                    $SIG{PIPE} = 'IGNORE';
                    print WRITER "$err";
                    close(WRITER);
                    exit(1);
                }
            }
            else
            {
                my $error_code = '';

                if ($pid == undef)
                {
                    $self->log("fork failed\n");
                    $failure_code = "fork: $!";
                }
                close(WRITER);
                
                $_ = <READER>;
                close(READER);

                if($_ ne '')
                {
                    chomp($_);
                    $self->log("exec failed\n");
                    $failure_code = "exec: $_";
                }

                if ($failure_code ne '')
                {
                    # fork or exec failed. kill rest of job and return an error

                    $failure_code =~ s/\n/\\n/g;
                    foreach(@job_id)
                    {
                        $pgid = getpgrp($_);

                        $pgid == -1 ? kill($signo{TERM}, $_) :
                            kill(-$signo{TERM}, $pgid);

                        sleep(5);

                        $pgid == -1 ? kill($signo{KILL}, $_) :
                            kill(-$signo{KILL}, $pgid);

                    }

                    local(*ERR);
                    open(ERR, '>' . $description->stderr());
                    print ERR "$failure_code\n";
                    close(ERR);

                    $self->respond({GT3_FAILURE_MESSAGE => $failure_code });
                    return Globus::GRAM::Error::JOB_EXECUTION_FAILED;
                }
                push(@job_id, $pid);
            }
        }
    }
    $merge_file->close() if defined($merge_file);

    $description->add('jobid', join(',', @job_id));
    return { JOB_STATE => Globus::GRAM::JobState::ACTIVE,
             JOB_ID => join(',', @job_id) };
}

sub poll
{
    my $self = shift;
    my $description = $self->{JobDescription};
    my $state;

    my $jobid = $description->jobid();

    if(!defined $jobid)
    {
        $self->log("poll: job id defined!");
        return { JOB_STATE => Globus::GRAM::JobState::FAILED };
    }

    $self->log("polling job " . $jobid);
    $_ = kill(0, split(/,/, $jobid));

    if($_ > 0)
    {
        $state = Globus::GRAM::JobState::ACTIVE;
    }
    else
    {
        $state = Globus::GRAM::JobState::DONE;
    }
    if($self->{STDIO_MERGER})
    {
        $self->{STDIO_MERGER}->poll($state == Globus::GRAM::JobState::DONE);
    }

    return { JOB_STATE => $state };
}

sub cancel
{
    my $self = shift;
    my $description = $self->{JobDescription};
    my $pgid;
    my $jobid = $description->jobid();

    if(!defined $jobid)
    {
        $self->log("cancel: no jobid defined!");
        return { JOB_STATE => Globus::GRAM::JobState::FAILED };
    }
    sleep(int(10+rand(10)));
    $self->log("cancel job " . $jobid);

    foreach (split(/,/,$jobid))
    {
        s/..*://;
        $pgid = getpgrp($_);
        
        $pgid == -1 ? kill($signo{TERM}, $_) :
            kill(-$signo{TERM}, $pgid);

        sleep(5);
        
        $pgid == -1 ? kill($signo{KILL}, $_) :
            kill(-$signo{KILL}, $pgid);
    }

    return { JOB_STATE => Globus::GRAM::JobState::FAILED };
}

sub escape_for_starter
{
    my $str = shift;

    $str =~ s/\\/\\\\/g;
    $str =~ s/;/\\;/g;
    $str =~ s/,/\\,/g;
    $str =~ s/\n/\\n/g;
    $str =~ s/=/\\=/g;

    return $str;
}

1;
