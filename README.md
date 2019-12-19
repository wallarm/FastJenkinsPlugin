# FAST plugin for Jenkins

Plugin for adding a Wallarm application security test stage in your pipeline.

## FAST setup and use

Requires an account on us1.my.wallarm.com or my.wallarm.com
After registration, you will need a FAST TOKEN which can be created at https://us1.my.wallarm.com/nodes
Creating a TestRun can be done here: https://us1.my.wallarm.com/testing/
After you're done recording your baselines you may reuse the TestRecord in other TestRuns (i.e. in a pipeline)

Any vulnerabilities found will be displayed here: https://us1.my.wallarm.com/vulnerabilities/

## Plugin use

The FAST plugin uses prerecorded TestRecords to run security tests as a separate build stage in your pipeline. It requires your target application to be up and running. FAST will use the same authentication as in the TestRecord. The host will be resolved via header-host unless a specific address is provided (via app_host and app_port - this option is recommended).

## Building locally

The plugin is written in JRuby using the jpi framework (more on jpi [here]( https://github.com/jenkinsci/jenkins.rb/wiki/Getting-Started-With-Ruby-Plugins)).

To build the plugin locally run the following code (you may use any Ruby, but jpi officially supports only JRuby):
```
gem install jpi
git clone https://gl.wallarm.com/wallarm-cloud/libs/FastJenkinsPlugin
cd FastJenkinsPlugin
jpi build
```

The plugin will appear in `pkg/wallarm.hpi`.

To import the plugin you need to add it via Jenkins:

1. Manage Plugins
2. Advanced
3. Upload Plugin (select wallarm.hpi)
4. Restart Jenkins for the new plugin to be fully loaded

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
