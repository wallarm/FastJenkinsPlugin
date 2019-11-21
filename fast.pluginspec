Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = "wallarm-fast"
  plugin.display_name = "Wallarm Fast"
  plugin.version = '1.0.0'
  plugin.description = 'Run security tests with Wallarm FAST'

  # You should create a wiki-page for your plugin when you publish it, see
  # https://wiki.jenkins-ci.org/display/JENKINS/Hosting+Plugins#HostingPlugins-AddingaWikipage
  # This line makes sure it's listed in your POM.
  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/Fast+Plugin'

  # The first argument is your user name for jenkins-ci.org.
  plugin.developed_by "mkirichecnko", "Mark Kirichenko <mkirichecnko@wallarm.com>"

  # This specifies where your code is hosted.
  # Alternatives include:
  #  :github => 'myuser/fast-plugin' (without myuser it defaults to jenkinsci)
  #  :git => 'git://repo.or.cz/fast-plugin.git'
  #  :svn => 'https://svn.jenkins-ci.org/trunk/hudson/plugins/fast-plugin'
  plugin.uses_repository :github => "fast-plugin"

  # This is a required dependency for every ruby plugin.
  plugin.depends_on 'ruby-runtime', '0.10'
end
