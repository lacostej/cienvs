require 'pty'
require 'expect'

def run_command(command)
  output = []
  PTY.spawn(command) do |command_stdout, command_stdin, pid|
    begin
      command_stdout.each do |l|
        line = l.chomp
        output << line
      end
    rescue Errno::EIO
      # This is expected on some linux systems, that indicates that the subcommand finished
      # and we kept trying to read, ignore it
    ensure
      command_stdout.close
      command_stdin.close
      Process.wait(pid)
    end
  end
  raise "#{$?.exited?} #{$?.stopped?} #{$?.signaled?} - #{$?.stopsig} - #{$?.termsig} -" unless $?.exitstatus == 0
  [$?.exitstatus, output.join("\n")]
end

def run_command2(command)
  output = []
  PTY.spawn(command) do |command_stdout, command_stdin, pid|
    output = ""
    begin
      a = command_stdout.expect(/foo.*/, 5)
      output = a[0] if a
    ensure
      command_stdout.close
      command_stdin.close
      Process.wait(pid)
    end
  end
  raise "#{$?.exited?} #{$?.stopped?} #{$?.signaled?} - #{$?.stopsig} - #{$?.termsig} -" unless $?.exitstatus == 0
  [$?.exitstatus, output]
end

def test_spawn(command)
  status, output = run_command(command)
  errors = []
  errors << "status was '#{status}'" unless status == 0
  errors << "output was '#{output}'" unless output == "foo"
  raise errors.join(" - ") unless errors.empty?
end

t = nil
pid = nil
if ENV['STRESS']
  t = Thread.new do |t|
    puts "Spawning stress"
    pid = spawn("stress -c 16 -t 99", pgroup: true)
    puts "Waiting #{pid}"
    Process.wait(pid)
    puts "#{pid} DONE"
  end
end

command = "echo foo"
#command = "sh -c 'echo foo'"
#command = "ruby -e \"puts 'foo'\""

if ARGV.count == 1
  command = ARGV[0]
end

puts "Will run command: '#{command}'"

errors = 0
2000.times do |i|
  begin
    test_spawn(command)
  rescue => e
    puts "ERROR #{i}: #{e}"
    errors += 1
  end
end

if t
  Process.kill(:SIGKILL, -pid)
  t.join
end

raise "Failed #{errors} times" unless errors == 0