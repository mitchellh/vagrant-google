# This tests that an instance can be halted correctly
shared_examples 'provider/halt' do |provider, options|
  unless options[:box]
    raise ArgumentError,
          "box option must be specified for provider: #{provider}"
  end

  include_context 'acceptance'

  before do
    environment.skeleton('generic')
    assert_execute('vagrant', 'box', 'add', 'basic', options[:box])
    assert_execute('vagrant', 'up', "--provider=#{provider}")
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should halt the machine and bring it back up' do
    status("Test: machine can be halted")
    halt_result = execute("vagrant", "halt")
    expect(halt_result).to exit_with(0)

    status("Test: machine can be brought up after halt")
    up_result = execute("vagrant", "up")
    expect(up_result).to exit_with(0)

    status("Test: machine is running after up")
    echo_result = execute("vagrant", "ssh", "-c", "echo foo")
    expect(echo_result).to exit_with(0)
    expect(echo_result.stdout).to match(/foo\n$/)
  end
end
