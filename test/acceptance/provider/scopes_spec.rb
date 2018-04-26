# This tests that account scopes can be configured correctly
# and that gcloud GCE aliases can be used.
# (see lib/fog/google/models/compute/server.rb in fog-google)
shared_examples 'provider/scopes' do |provider, options|
  unless options[:box]
    raise ArgumentError,
          "box option must be specified for provider: #{provider}"
  end

  include_context 'acceptance'

  before do
    environment.skeleton('scopes')
    assert_execute('vagrant', 'box', 'add', 'basic', options[:box])
    assert_execute('vagrant', 'up', "--provider=#{provider}")
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should bring up machine with scope definitions' do
    status("Test: machine is running after up")
    result = execute("vagrant", "ssh", "-c", "echo foo")
    expect(result).to exit_with(0)
    expect(result.stdout).to match(/foo\n$/)
  end
end
