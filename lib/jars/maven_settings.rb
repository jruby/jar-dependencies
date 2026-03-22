# frozen_string_literal: true

module Jars
  class MavenSettings
    class << self
      def local_settings
        @_jars_maven_local_settings_ = nil unless instance_variable_defined?(:@_jars_maven_local_settings_)
        if @_jars_maven_local_settings_.nil?
          settings = Jars.absolute('settings.xml')
          @_jars_maven_local_settings_ =
            if settings && File.exist?(settings)
              settings
            else
              false
            end
        end
        @_jars_maven_local_settings_ || nil
      end

      def user_settings
        @_jars_maven_user_settings_ = nil unless instance_variable_defined?(:@_jars_maven_user_settings_)
        if @_jars_maven_user_settings_.nil?
          if (settings = Jars.absolute(Jars.to_prop(MAVEN_SETTINGS)))
            unless File.exist?(settings)
              Jars.warn { "configured ENV['#{MAVEN_SETTINGS}'] = '#{settings}' not found" }
              settings = false
            end
          else # use maven default (user) settings
            settings = File.join(Jars.user_home, '.m2', 'settings.xml')
            settings = false unless File.exist?(settings)
          end
          @_jars_maven_user_settings_ = settings
        end
        @_jars_maven_user_settings_ || nil
      end

      def settings
        @_jars_maven_settings_ = nil unless instance_variable_defined?(:@_jars_maven_settings_)
        local_settings || user_settings if @_jars_maven_settings_.nil?
      end

      def global_settings
        @_jars_maven_global_settings_ = nil unless instance_variable_defined?(:@_jars_maven_global_settings_)
        if @_jars_maven_global_settings_.nil?
          if (mvn_home = ENV['M2_HOME'] || ENV['MAVEN_HOME'])
            settings = File.join(mvn_home, 'conf/settings.xml')
            settings = false unless File.exist?(settings)
          else
            settings = false
          end
          @_jars_maven_global_settings_ = settings
        end
        @_jars_maven_global_settings_ || nil
      end

      def reset
        instance_variables.each { |var| instance_variable_set(var, nil) }
      end
    end
  end
end
