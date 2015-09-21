# This tests that an instance can be reloaded correctly
shared_examples 'provider/reload' do |provider, options|
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

  it 'should reload the machine correctly' do
    status("Test: machine can be reloaded")
    reload_result = execute("vagrant", "reload")
    expect(reload_result).to exit_with(0)

    echo_result = execute("vagrant", "ssh", "-c", "echo foo")
    expect(echo_result).to exit_with(0)
    expect(echo_result.stdout).to match(/foo\n$/)
  end
end
