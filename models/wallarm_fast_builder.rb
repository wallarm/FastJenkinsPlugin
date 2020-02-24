# frozen_string_literal: true

# A single build step in the entire build process
class WallarmFastBuilder < Jenkins::Tasks::Builder
  display_name 'Wallarm Security Tests'

  attr_accessor :wallarm_api_token,
                :app_host,
                :app_port,
                :fast_port,
                :fast_name,
                :policy_id,
                :test_record_id,
                :wallarm_api_host,
                :test_run_name,
                :test_run_desc,
                :record,
                :stop_on_first_fail,
                :fail_build,
                :without_sudo,
                :local_docker_network,
                :local_docker_ip,
                :wallarm_version,
                :inactivity_timeout,
                :test_run_rps,
                :allowed_hosts

  # Invoked with the form parameters when this extension point
  # is created from a configuration screen.
  def initialize(attrs = {})
    attrs.delete_if { |_key, value| value.is_a?(String) && value.empty? }

    converted_attrs = attrs.map do |key, value|
      converted_value = [true, false].include?(value) ? value.to_s : value
      [key, converted_value]
    end

    attrs = Hash[*converted_attrs.flatten]

    @wallarm_api_token    = attrs.fetch('wallarm_api_token', '')
    @app_host             = attrs.fetch('app_host', '')
    @app_port             = attrs.fetch('app_port', nil)
    @fast_port            = attrs.fetch('fast_port', nil)
    @policy_id            = attrs.fetch('policy_id', nil)

    @test_record_id       = attrs.fetch('test_record_id', nil)
    @wallarm_api_host     = attrs.fetch('wallarm_api_host', 'us1.api.wallarm.com')
    @test_run_name        = attrs.fetch('test_run_name', nil)
    @test_run_desc        = attrs.fetch('test_run_desc', nil)
    @record               = attrs.fetch('record', 'false')

    @stop_on_first_fail   = attrs.fetch('stop_on_first_fail', 'false')
    @fail_build           = attrs.fetch('fail_build', 'true')
    @without_sudo         = attrs.fetch('without_sudo', 'false')
    @local_docker_network = attrs.fetch('local_docker_network', nil) # used when target application is inside a docker network
    @local_docker_ip      = attrs.fetch('local_docker_ip', nil) # used when FAST needs to be referenced as a proxy

    @wallarm_version      = attrs.fetch('wallarm_version', 'latest')
    @inactivity_timeout   = attrs.fetch('inactivity_timeout', nil)
    @test_run_rps         = attrs.fetch('test_run_rps', nil)
    @allowed_hosts        = attrs.fetch('allowed_hosts', nil)

    default_fast_name = true?(@record) ? 'wallarm_fast_recorder' : 'wallarm_fast_tester'
    @fast_name = attrs.fetch('fast_name', default_fast_name)
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
    fix_bools
    cmd = []
    add_required_params(cmd)
    add_optional_params(cmd)
    add_params_with_default_values(cmd)

    if @record
      record_baselines(cmd, build, launcher, listener)
    else
      run_tests(cmd, build, launcher, listener)
    end
  end

  private

  # Due to errors for the jpi gem when saving/loading boolean values
  # we store them as strings 'true' and 'false'.
  # for proper operation we hotswap them back into boolean form when required
  def fix_bools
    @record             = true?(@record)
    @stop_on_first_fail = true?(@stop_on_first_fail)
    @fail_build         = true?(@fail_build)
    @without_sudo       = true?(@without_sudo)
  end

  def true?(val)
    val.to_s.downcase == "true"
  end

  # Due to jpi saving empty strings as '' instead of a more common nil
  # this makes common ruby approaches to testing for empty values a bit more complicated
  def not_empty?(param)
    param && !param.empty?
  end

  def add_required_params(cmd)
    cmd << 'docker run --rm'
    cmd << "--name '#{@fast_name}'"

    if @record
      cmd << '-d'
      cmd << '-e CI_MODE=recording'
      cmd << "-p #{@fast_port}:8080"
    else
      cmd << '-e CI_MODE=testing'
      if not_empty?(@app_host)
        uri = "http://#{@app_host}"
        uri += ":#{@app_port}" if not_empty?(@app_port)
        cmd << "-e TEST_RUN_URI=#{uri}"
      end
    end

    cmd << '-e WALLARM_API_TOKEN=$WALLARM_API_TOKEN'
  end

  def add_optional_params(cmd)
    cmd << "-e TEST_RUN_POLICY_ID=#{@policy_id}" if not_empty?(@policy_id)
    cmd << "-e TEST_RECORD_ID=#{@test_record_id}" if not_empty?(@test_record_id)
    cmd << "-e INACTIVITY_TIMEOUT=#{@inactivity_timeout}" if not_empty?(@inactivity_timeout)
    cmd << "--net #{@local_docker_network}" if not_empty?(@local_docker_network)
    cmd << "--ip #{@local_docker_ip}" if not_empty?(@local_docker_ip)

    cmd << "-e TEST_RUN_NAME='#{@test_run_name}'" if not_empty?(@test_run_name)
    cmd << "-e TEST_RUN_DESC='#{@test_run_desc}'" if not_empty?(@test_run_desc)
    cmd << "-e TEST_RUN_STOP_ON_FIRST_FAIL=#{@stop_on_first_fail}" if @stop_on_first_fail
    cmd << "-e TEST_RUN_RPS=#{@test_run_rps}" if not_empty?(@test_run_rps)
    cmd << "-e ALLOWED_HOSTS='#{@allowed_hosts}'" if not_empty?(@allowed_hosts)
  end

  def add_params_with_default_values(cmd)
    cmd << "-e WALLARM_API_HOST=#{@wallarm_api_host}"
    cmd << "wallarm/fast:#{@wallarm_version}"
  end

  def shell_command(launcher, cmd, env = {})
    r, w = IO.pipe

    execute_cmd(launcher, cmd, env, out: w)
    w.close

    result = r.read.chomp
    r.close
    result
  end

  def execute_cmd(launcher, cmd, env = {}, opts = {})
    cmd.unshift('sudo') unless @without_sudo || cmd.first == 'sudo'
    launcher.execute(env, cmd.join(' '), opts)
  end

  def record_baselines(cmd, build, launcher, listener)
    listener.info('Launching FAST for recording...')

    docker_id = shell_command(launcher, cmd, 'WALLARM_API_TOKEN' => @wallarm_api_token.to_s)
    if docker_id.include? 'Error'
      listener.error(docker_id)
      build.halt 'Cannot start FAST docker due to docker conflict'
    end

    if docker_id.include? 'permission denied'
      listener.error(docker_id)
      build.halt 'Enable sudo or add docker to sudoers file to run this command'
    end

    if id_match = docker_id.match(/[0-9a-z]{64}/)
      docker_id = id_match[0]
    else
      build.halt "Unknown error / cannot parse docker id: #{docker_id}"
    end

    listener.info('Waiting for ready status')
    cmd_for_health = ["docker exec -t #{docker_id} supervisorctl status proxy"]

    10.times do |i|
      sleep 5

      health = shell_command(launcher, cmd_for_health)
      listener.info("health check: #{health}")
      break if health.include? 'RUNNING'

      next unless i == 9

      kill_cmd = new_cmd
      kill_cmd << "docker kill #{docker_id}"
      shell_command(launcher, kill_cmd)
      build.halt 'Cannot start FAST docker due to timeout on proxy'
    end

    listener.info('FAST is ready to record')

    # No cleanup here.
    # We must release this docker and rely on it finishing on it's own or by outside means
    # or get killed user-side since we have no control / way of finding the right one
    # Otherwise it will be hanging
  end

  def run_tests(cmd, build, launcher, listener)
    # there may be a running fast recorder
    # we have no way of knowing if one exists,
    # or what name it has

    listener.info('Starting Wallarm FAST tests...')
    test_run_status = execute_cmd(
      launcher,
      cmd,
      { 'WALLARM_API_TOKEN' => @wallarm_api_token.to_s },
      out: listener
    )

    listener.info("Test run status: #{test_run_status}")
    listener.info('Finishing Wallarm FAST tests...')

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
    execute_cmd(launcher, ["docker kill #{fast_name}"])
  end
end
