# frozen_string_literal: true

# A single build step in the entire build process
class WallarmFastBuilder < Jenkins::Tasks::Builder
  display_name 'Wallarm Security Tests'

  attr_accessor :wallarm_api_token,
                :app_host,
                :app_port,
                :policy_id,
                :test_record_id,
                :wallarm_api_host,
                :test_run_name,
                :test_run_desc,
                :stop_on_first_fail,
                :fail_build,
                :without_sudo,
                :local_docker_network,
                :wallarm_version,
                :inactivity_timeout,
                :test_run_rps

  # Invoked with the form parameters when this extension point
  # is created from a configuration screen.
  def initialize(attrs = {})
    @wallarm_api_token    = attrs.fetch('wallarm_api_token', '')
    @app_host             = attrs.fetch('app_host', nil)
    @app_port             = attrs.fetch('app_port', 8080)
    @policy_id            = attrs.fetch('policy_id', nil)
    @test_record_id       = attrs.fetch('test_record_id', nil)
    @wallarm_api_host     = string_fetch(attrs['wallarm_api_host'], 'us1.api.wallarm.com')

    @test_run_name        = attrs.fetch('test_run_name', nil)
    @test_run_desc        = attrs.fetch('test_run_desc', nil)
    @stop_on_first_fail   = attrs.fetch('stop_on_first_fail', false)
    @fail_build           = attrs.fetch('fail_build', true)

    @without_sudo         = attrs.fetch('without_sudo', false)
    @local_docker_network = attrs.fetch('local_docker_network', nil) # used when target application is inside a docker network
    @wallarm_version      = string_fetch(attrs['wallarm_version'], 'latest')
    @inactivity_timeout   = attrs.fetch('inactivity_timeout', nil)
    @test_run_rps         = attrs.fetch('test_run_rps', nil)
  end

  ##
  # Runs before the build begins
  #
  # @param [Jenkins::Model::Build] build the build which will begin
  # @param [Jenkins::Model::Listener] listener the listener for this build.
  def prebuild(build, listener); end

  ##
  # Runs the step over the given build and reports the progress to the listener.
  #
  # @param [Jenkins::Model::Build] build on which to run this step
  # @param [Jenkins::Launcher] launcher the launcher that can run code on the node running this build
  # @param [Jenkins::Model::Listener] listener the listener for this build.
  def perform(build, launcher, listener)
    @app_port = '8080' if @app_port.nil? || @app_port.empty?
    @app_host = '127.0.0.1' if @app_host.nil? || @app_host.empty?

    cmd = []

    add_required_params(cmd)
    add_optional_params(cmd)
    add_params_with_default_values(cmd)

    listener.info('Starting wallarm FAST tests...')
    test_run_status = launcher.execute({'WALLARM_API_TOKEN' => @wallarm_api_token.to_s}, cmd.join(' '), out: listener)
    listener.info("Test run status: #{test_run_status}")
    listener.info('Finishing wallarm FAST tests...')

    if test_run_status != 0
      if @fail_build
        build.halt 'Security tests failed! Halting build'
      else
        listener.info('Security tests failed! Build set to not fail')
      end
    else
      listener.info('Security tests passed!')
    end
  ensure
    cmd = []
    cmd << 'sudo' unless @without_sudo
    cmd << 'docker kill wallarm_fast'
    launcher.execute(cmd.join(' '))
  end

  private

  def not_empty?(param)
    param && !param.empty?
  end

  def string_fetch(param, default)
    if not_empty?(param)
      param
    else
      default
    end
  end

  def add_required_params(cmd)
    cmd << 'sudo' unless @without_sudo
    cmd << 'docker run --rm'
    cmd << '--name wallarm_fast'
    cmd << '-e CI_MODE=testing'
    cmd << "-e TEST_RUN_URI=http://#{@app_host}:#{@app_port}"
    cmd << "-e WALLARM_API_TOKEN=$WALLARM_API_TOKEN"
  end

  def add_optional_params(cmd)
    cmd << "-e POLICY_ID=#{@policy_id}" if not_empty?(@policy_id)
    cmd << "-e TEST_RECORD_ID=#{@test_record_id}" if not_empty?(@test_record_id)
    cmd << "-e INACTIVITY_TIMEOUT=#{@inactivity_timeout}" if not_empty?(@inactivity_timeout)
    cmd << "--net #{@local_docker_network}" if not_empty?(@local_docker_network)

    cmd << "-e TEST_RUN_NAME='#{@test_run_name}'" if not_empty?(@test_run_name)
    cmd << "-e TEST_RUN_DESC='#{@test_run_desc}'" if not_empty?(@test_run_desc)
    cmd << "-e TEST_RUN_STOP_ON_FIRST_FAIL=#{@stop_on_first_fail}" if @stop_on_first_fail
    cmd << "-e TEST_RUN_RPS=#{@test_run_rps}" if not_empty?(@test_run_rps)
  end

  def add_params_with_default_values(cmd)
    cmd << "-e WALLARM_API_HOST=#{@wallarm_api_host}"
    cmd << "wallarm/fast:#{@wallarm_version}"
  end
end
