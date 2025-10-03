#! /usr/bin/env ruby
require "erb"
require 'fileutils'
require "yaml"
require 'json'
require 'optparse'
require 'pathname'


options = {
  repo_list: [],
  secret_type: "repo"
}

OptionParser.new do |parser|
  parser.banner = "Usage: #{$PROGRAM_NAME} [options]"
  parser.on("--secretname NAME", "The name of the secret") do |name|
    options[:secret_name] = name
  end
  parser.on("--reponame REPO", "The org/repo_name name (e.g., 'rancher/rancher-agent')") do |repo|
    options[:full_repo_name] = repo
  end
  parser.on("--repolist PATH", "Path to a file containing a list of full repository names, one per line. ") do |path|
      if File.exist?(path)
        options[:repo_list] = File.readlines(path).map(&:chomp)
      else
        puts "The file specified for --repolist does not exist."
        exit
      end
  end
  parser.on("--template TEMPLATE", "The kind of secret (dockerhub, aws, githubtoken, githubapp or apikey) ") do |template|
    options[:template] = template
  end
  parser.on("--secrettype TYPE", "The vault secret type (repo, org or branch )") do |type|
    options[:secret_type] = type
  end
  parser.on("--org ORG", "The org name for the vault secret path") do |org|
    options[:org] = org
  end
  parser.on("--secretpath SECRETPATH", "Specify the secretpath yourself") do |path|
    options[:secret_path] = path
  end
  parser.on("--privatekey-secretpath SECRETPATH", "Specify the secretpath yourself") do |path|
    options[:privatekey_secret_path] = path
  end
  parser.on("--tokenapp API", "Software apitoken belongs to") do |token|
    options[:token_app] = token
  end
end.parse!

if options[:template].nil? && (options[:full_repo_name].nil?   || options[:repo_list].empty?)
  puts "Either --template and --fullrepo or --repolist option is required."
  exit
end

if options[:full_repo_name]
  options[:repo_list] << options[:full_repo_name] unless options[:repo_list].include?(options[:full_repo_name])
end


def log_to_file(message)
  log_file_path = "./logs.log" 
  File.open(log_file_path, 'a') do |file|
    file.puts(message)
  end
end

def add_new_match(push_secret_yaml,full_repo_name, kube_secret_key, push_secret_name,secret_type,secret_path_suffix, options)

  secret_path = options[:secret_path] || "secret/data/github/#{secret_type}/#{full_repo_name}/#{secret_path_suffix}"
  match_exists = push_secret_yaml['spec']['data'].any? do |entry|
    entry['match']['remoteRef']['remoteKey'] == secret_path
  end

  unless match_exists
    new_match = {
      'match' => {
        'remoteRef' => {
          'remoteKey' => secret_path,
        },
        'secretKey' => kube_secret_key,
      }
    }
    push_secret_yaml['spec']['data'] << new_match
  else
    log_to_file("Match for secretPath: #{secret_path} already exists in Push Secret #{push_secret_name}")
  end
end

secret_name = options[:secret_name]
repo_list = options[:repo_list]
secret_type = options[:secret_type]

template_file, credentials_json, kube_secret_key, secret_path_suffix  = case options[:template]
when /^d(ocker)?h(ub)?$/i then
  template_file = "templates/dockerhub-template.yaml"
  credentials_json = '{"username":"{{  .username }}","password":"{{ .password }}"}'
  kube_secret_key = "credentials"
  secret_path_suffix = "dockerhub/#{options.fetch(:org)}/credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^git(hub)?(token)?$/i then
  template_file = "templates/github-template.yaml"
  credentials_json = '{"owner":"{{  .owner }}","token":"{{ .token }}"}'
  kube_secret_key = "credentials"
  secret_path_suffix = "github/rancherbot/#{options.fetch(:org)}/credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^git(hub)app?$/i then
  template_file = "templates/github-app-template.yaml"
  credentials_json = '{"appId":"{{  .appId }}","privateKey":"{{ .privateKey }}"}'
  kube_secret_key = "credentials"
  secret_path_suffix = "github/app-credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^prime?$/i then
  template_file = "templates/prime-template.yaml"
  credentials_json = '{"username":"{{  .username }}","password":"{{ .password}}","registry":"{{ .registry}}"}'
  kube_secret_key = "credentials"
  secret_path_suffix = options[:secret_path] ? "" : "#{options.fetch(:token_app, 'rancher-prime-registry')}/credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

  # when /^google-auth?$/i then
#   template_file = "templates/google-auth-template.yaml"
#   credentials_json = '{"credential":"{{ .password }}"}'
#   kube_secret_key = "credentials"
#   secret_path_suffix = "google-auth/#{options.fetch(:org)}/credentials"
#   [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^password?$/i then
  unless options[:secret_path] || options[:token_app]
    puts "Error: If not specifying --secretpath, you must specify the application name for the API token using --tokenapp."
    exit(1)
  end
  template_file = "templates/password-template.yaml"
  credentials_json = "{{ .password }}"
  kube_secret_key = "credentials"
  secret_path_suffix = options[:secret_path] ? "" : "#{options.fetch(:token_app, 'default')}/credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^api(token)?$/i then
  unless options[:secret_path] || options[:token_app]
    puts "Error: If not specifying --secretpath, you must specify the application name for the API token using --tokenapp."
    exit(1)
  end

  template_file = "templates/apitoken-template.yaml"
  kube_secret_key = "token"
  credentials_json = ""
  secret_path_suffix = options[:secret_path] ? "" : "#{options.fetch(:token_app, 'default')}/token"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^(aws|amazon)$/i then
  template_file = "templates/aws-template.yaml"
  credentials_json = '{"accessKeyId":"{{  .accessKeyId }}","secretAccessKey":"{{ .secretAccessKey }}"}'
  kube_secret_key = "credentials"
  secret_path_suffix = "aws/#{options.fetch(:secret_name)}/credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

when /^prime-artifacts$/i then
  template_file = "templates/prime-artifacts.yaml"
  credentials_json = '{"accessKeyId":"{{  .accessKeyId }}","secretAccessKey":"{{ .secretAccessKey}}","primeArtifactsBucketName":"{{ .primeArtifactsBucketName }}"}'
  kube_secret_key = "credentials"
  secret_path_suffix = options[:secret_path] ? "" : "#{options.fetch(:token_app, 'rancher-prime-artifacts')}/credentials"
  [template_file, credentials_json, kube_secret_key, secret_path_suffix ]

else raise TypeError, "no template for #{options[:template]}"
end

template = YAML.load_file("./scripts/#{template_file}")
namespace = "secrets"

external_secret_template = template['external_secret_template']
external_secret_name = "import-#{secret_name}"
external_secret_path = "./manifests/secrets/resources/ExternalSecret"
external_secret_file = Pathname("#{external_secret_path}/#{external_secret_name}.yaml")

push_secret_template = template['push_secret_template']
push_secret_name = "export-#{secret_name}"
push_secret_path = "./manifests/secrets/resources/PushSecret"
push_secret_file = Pathname("#{push_secret_path}/#{push_secret_name}.yaml")

unless external_secret_file.exist?
  context = {
    secret_name: secret_name,
    privatekey_secret_path: options[:privatekey_secret_path],
    external_secret_name: external_secret_name,
    namespace: namespace,
    credentials_json: credentials_json
  }

  external_secret_yaml = ERB.new(external_secret_template).result_with_hash(context)
  $stdout.puts YAML.dump YAML.load external_secret_yaml
else
  log_to_file(" External Secret at: #{external_secret_file} already exist")
end

unless push_secret_file.exist?
  initial_org_repo_name = repo_list.first
  secret_path = options[:secret_path] || "secret/data/github/#{secret_type}/#{initial_org_repo_name}/#{secret_path_suffix}"
  context = {
    push_secret_name: push_secret_name,
    secret_path: secret_path,
    kube_secret_key: kube_secret_key,
    external_secret_name: external_secret_name
  }
  push_secret_yaml = YAML.load(ERB.new(push_secret_template).result_with_hash(context))
else
  log_to_file(" Push Secret at: #{push_secret_file} already exist")
  push_secret_yaml = YAML.load_file(push_secret_file)
end

repo_list.each do |full_repo_name|
  add_new_match(push_secret_yaml, full_repo_name, kube_secret_key,push_secret_name,secret_type,secret_path_suffix,options)
end
push_secret_yaml['spec']['data'].sort_by! { |item| item['match']['remoteRef']['remoteKey'] }
$stdout.puts YAML.dump(push_secret_yaml)

#TODO
# org secret path needs to be updated
# sort the data.match array
