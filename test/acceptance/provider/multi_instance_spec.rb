# This tests that multiple instances can be brought up correctly
shared_examples 'provider/multi_instance' do |provider, options|
  unless options[:box]
    raise ArgumentError,
          "box option must be specified for provider: #{provider}"
  end

  include_context 'acceptance'

  before do
    environment.skeleton('multi_instance')
    assert_execute('vagrant', 'box', 'add', 'basic', options[:box])
    assert_execute('vagrant', 'up', "--provider=#{provider}")
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should bring up 2 machines in different zones' do
    status("Test: both machines are running after up")
    status("Test: machine1 is running after up")
    result1 = execute("vagrant", "ssh", "z1a", "-c", "echo foo")
    expect(result1).to exit_with(0)
    expect(result1.stdout).to match(/foo\n$/)
    status("Test: machine2 is running after up")
    result1 = execute("vagrant", "ssh", "z1b", "-c", "echo foo")
    expect(result1).to exit_with(0)
    expect(result1.stdout).to match(/foo\n$/)
  end
end
