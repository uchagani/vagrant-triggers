require "log4r"
require "shellwords"
require "vagrant/util/subprocess"

module VagrantPlugins
  module Triggers
    class DSL
      def initialize(ui, options = {})
        @logger  = Log4r::Logger.new("vagrant::plugins::triggers::dsl")
        @options = options
        @ui      = ui
      end

      def run(raw_command, options = {})
        @ui.info I18n.t("vagrant_triggers.action.trigger.executing_command", :command => raw_command)
        command     = Shellwords.shellsplit(raw_command)
        env_backup  = ENV.to_hash
        begin
          build_environment
          result = Vagrant::Util::Subprocess.execute(command[0], *command[1..-1])
        rescue Vagrant::Errors::CommandUnavailable, Vagrant::Errors::CommandUnavailableWindows
          raise Errors::CommandUnavailable, :command => command[0]
        ensure
          ENV.replace(env_backup)
        end
        if result.exit_code != 0 && !@options[:force]
          raise Errors::CommandFailed, :command => raw_command, :stderr => result.stderr
        end
        if @options[:stdout]
          @ui.info I18n.t("vagrant_triggers.action.trigger.command_output", :output => result.stdout)
        end
      end
      alias_method :execute, :run

      def info(message)
        @ui.info(message)
      end

      private

      def build_environment
        @logger.debug("Original environment: #{ENV.inspect}")

        # Remove GEM_ environment variables
        ["GEM_HOME", "GEM_PATH", "GEMRC"].each { |gem_var| ENV.delete(gem_var) }

        # Create the new PATH removing Vagrant bin directory
        # and appending directories specified through the
        # :append_to_path option
        new_path  = ENV["VAGRANT_INSTALLER_ENV"] ? ENV["PATH"].gsub(/#{ENV["VAGRANT_INSTALLER_EMBEDDED_DIR"]}.*?#{File::PATH_SEPARATOR}/, "") : ENV["PATH"]
        new_path += Array(@options[:append_to_path]).map { |dir| "#{File::PATH_SEPARATOR}#{dir}" }.join
        ENV["PATH"] = new_path
        @logger.debug("PATH modifed: #{ENV["PATH"]}")

        # Add the VAGRANT_NO_TRIGGERS variable to avoid loops
        ENV["VAGRANT_NO_TRIGGERS"] = "1"
      end
    end
  end
end