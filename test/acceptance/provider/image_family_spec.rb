# This tests that an instance referenced by image family can be started properly
shared_examples 'provider/image_family' do |provider, options|
  unless options[:box]
    raise ArgumentError,
          "box option must be specified for provider: #{provider}"
  end

  include_context 'acceptance'

  before do
    environment.skeleton('image_family')
    assert_execute('vagrant', 'box', 'add', 'basic', options[:box])
    assert_execute('vagrant', 'up', "--provider=#{provider}")
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should bring up machine with image_family option' do
    status("Test: machine is running after up")
    result = execute("vagrant", "ssh", "-c", "echo foo")
    expect(result).to exit_with(0)
    expect(result.stdout).to match(/foo\n$/)
  end
end
