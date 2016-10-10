# Encoding: UTF-8
#
# Cookbook Name:: mac-app-store
# Library:: helpers_app
#
# Copyright 2015-2016, Jonathan Hartman
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/shell_out'

module MacAppStore
  module Helpers
    # A set of helper methods for interacting with App Store apps via Mas.
    #
    # @author Jonathan Hartman <j@p4nt5.com>
    class App
      class << self
        include Chef::Mixin::ShellOut

        attr_accessor :user

        #
        # Check whether a given app has upgrades available.
        #
        # @param name [String] an app name to search for
        #
        # @return [TrueClass, FalseClass] whether the app has an upgrade
        #
        def upgradable?(name)
          apps = shell_out('mas outdated', user: user).stdout.lines.map do |l|
            {
              id: l.split(' ')[0],
              name: l.split(' ')[1..-2].join(' ')
            }
          end
          app_id = app_id_for?(name)
          apps.find { |a| a[:id] == app_id } ? true : false
        end

        #
        # Chef whether a given app is currently installed.
        #
        # @param name [String] an app name to search for
        #
        # @return [TrueClass, FalseClass] whether the app is installed
        #
        def installed?(name)
          apps = shell_out('mas list', user: user).stdout.lines.map do |l|
            l.split(' ')[0]
          end
          apps.include?(app_id_for?(name))
        end

        #
        # Search for an app's ID by its name.
        #
        # @param name [String] an app name to search for
        #
        # @return [String] the app's corresponding ID
        #
        def bin_to_hex(s)
          s.each_byte.map { |b| b.to_s(16) }.join(' ')
        end

        def app_id_for?(name)
          Chef::Log.info("name: #{bin_to_hex name}")
          search = shell_out("mas search '#{name}'", user: user).stdout
          app_line = search.lines.find do |l|
            Chef::Log.info("line: #{bin_to_hex l}")
            Chef::Log.info("l.rstrip.split(' ')[1..-1].join(' '): #{bin_to_hex l.rstrip.split(' ')[1..-1].join(' ')}")
            l.rstrip.split(' ')[1..-1].join(' ') == name
          end
          app_id = app_line && app_line.split(' ')[0]
          Chef::Log.info("app_line: #{app_line}")
          Chef::Log.info("app_id: #{app_id}")
          app_id
        end
      end
    end
  end
end
