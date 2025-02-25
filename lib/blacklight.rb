# frozen_string_literal: true

require 'kaminari'
require 'blacklight/open_struct_with_hash_access'
require 'blacklight/nested_open_struct_with_hash_access'
require 'jbuilder'

module Blacklight
  autoload :AbstractRepository, 'blacklight/abstract_repository'
  autoload :Component, 'blacklight/component'
  autoload :Configuration, 'blacklight/configuration'
  autoload :Exceptions,  'blacklight/exceptions'
  autoload :Parameters,  'blacklight/parameters'
  autoload :Routes,      'blacklight/routes'
  autoload :RuntimeRegistry, 'blacklight/runtime_registry'
  autoload :SearchBuilder, 'blacklight/search_builder'
  autoload :SearchState, 'blacklight/search_state'
  autoload :Solr, 'blacklight/solr'

  require 'blacklight/version'
  require 'blacklight/engine' if defined?(Rails)

  def self.blacklight_config_file
    "#{::Rails.root}/config/blacklight.yml"
  end

  ##
  # The default index connection for the search index
  def self.default_index
    Blacklight::RuntimeRegistry.connection ||= repository_class.new(default_configuration)
  end

  def self.default_index=(repository)
    Blacklight::RuntimeRegistry.connection = repository
  end

  ##
  # The configured repository class. By convention, this is
  # the class Blacklight::(name of the adapter)::Repository, e.g.
  #   elastic_search => Blacklight::ElasticSearch::Repository
  def self.repository_class
    case connection_config[:adapter]
    when 'solr'
      Blacklight::Solr::Repository
    when /::/
      connection_config[:adapter].constantize
    else
      raise "The value for :adapter was not found in the blacklight.yml config" unless connection_config.key? :adapter

      Blacklight.const_get("#{connection_config.fetch(:adapter)}/Repository".classify)
    end
  end

  ##
  # The default Blacklight configuration.
  def self.default_configuration
    Blacklight::Configuration.new
  end

  def self.connection_config
    Blacklight::RuntimeRegistry.connection_config ||= blacklight_yml[::Rails.env]&.symbolize_keys if blacklight_yml?
  end

  def self.connection_config=(value)
    Blacklight::RuntimeRegistry.connection_config = value
  end

  def defaults_version
    @defaults_version ||= blacklight_yml['load_defaults'] ||
                          # this config parameter was introduced in Blacklight 7.11, so to be safe,
                          # we pin any 7.x app to the 7.10 behavior
                          (Blacklight::VERSION.starts_with?('7') && '7.10.0') ||
                          Blacklight::VERSION

    @defaults_version == 'latest' ? Blacklight::VERSION : @defaults_version
  end

  def self.blacklight_yml
    require 'erb'
    require 'yaml'

    return @blacklight_yml if @blacklight_yml
    unless blacklight_yml?
      raise "You are missing a configuration file: #{blacklight_config_file}. Have you run \"rails generate blacklight:install\"?"
    end

    begin
      blacklight_erb = ERB.new(File.read(blacklight_config_file)).result(binding)
    rescue StandardError, SyntaxError => e
      raise("#{blacklight_config_file} was found, but could not be parsed with ERB. \n#{e.inspect}")
    end

    begin
      @blacklight_yml = if RUBY_VERSION > '2.6'
                          YAML.safe_load(blacklight_erb, aliases: true)
                        else
                          YAML.safe_load(blacklight_erb, [], [], true)
                        end
    rescue => e
      raise("#{blacklight_config_file} was found, but could not be parsed.\n#{e.inspect}")
    end

    if @blacklight_yml.nil? || !@blacklight_yml.is_a?(Hash)
      raise("#{blacklight_config_file} was found, but was blank or malformed.\n")
    end

    @blacklight_yml
  end

  def self.blacklight_yml?
    File.exist?(blacklight_config_file)
  end

  def self.logger
    @logger ||= (::Rails.logger if defined? Rails && Rails.respond_to?(:logger))
  end

  def self.logger= logger
    @logger = logger
  end

  #############
  # Methods for figuring out path to BL plugin, and then locate various files
  # either in the app itself or defaults in the plugin -- whether you are running
  # from the plugin itself or from an actual app using te plugin.
  # In a seperate module so it can be used by both Blacklight class, and
  # by rake tasks without loading the whole Rails environment.
  #############

  # returns the full path the the blacklight plugin installation
  def self.root
    @root ||= File.expand_path(File.dirname(File.dirname(__FILE__)))
  end

  def self.deprecation
    @deprecation ||= ActiveSupport::Deprecation.new('9.0', 'Blacklight')
  end
end
