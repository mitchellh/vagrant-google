# This test check that the instance groups logic doesn't break the provisioning
# process.
#
# TODO: Reach out using Fog credentials and verify group existence.
# TODO: Clean up the created instance groups automatically
shared_examples 'provider/instance_groups' do |provider, options|
  unless options[:box]
    raise ArgumentError,
          "box option must be specified for provider: #{provider}"
  end

  include_context 'acceptance'

  before do
    environment.skeleton('instance_groups')
    assert_execute('vagrant', 'box', 'add', 'basic', options[:box])
    assert_execute('vagrant', 'up', "--provider=#{provider}")
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should bring up machine with an instance group' do
    status("Test: machine is running after up")
    result = execute("vagrant", "ssh", "-c", "echo foo")
    expect(result).to exit_with(0)
    expect(result.stdout).to match(/foo\n$/)
  end
end
