require 'sinatra'
require 'json'
require 'yaml'
require 'github_api'

@config = YAML.load_file('./config.yml')

# Writes some data to a file in the current directory.  The file will have the current timestamp,
# to differentiate it from others.
#
# = Parameters
# * <tt>text</tt> -     The text that should be written to a file.
# * <tt>filename</tt> - The appended "tag" of the file name.  Defaults to "POST".
#
def write_stuff(text, filename="POST")
  File.open(Dir.getwd + '/' + Time.now.to_i.to_s + '-' + filename + '.txt', 'w+') { |f| f.write(text) }
end

# Basic landing page for the basic app.
get '/' do
  "Hey there."
end

# This is the route that receives the GitHub payload.
post '/pr' do
  # This is the payload sent by GitHub on every repository action.
  @load = JSON.parse(params['payload'])

  # Basic user and repo information.  You can figure out these values from this standard: git@github.com:@user/@repo.git.
  @user, @repo = @config['user'], @config['repo']

  # Basic GitHub auth.
  gh = Github.new basic_auth: "#{@config['git_user']}:#{@config['git_pass']}"

  # Commit listener.
  if @load['before'] && @load['after']
    # The repository to fetch the diff from.
    a = @load['repository']['url'].gsub(/https?\:\/\/github\.com\//i, '') + '.git'
    # The branch to fetch the diff from.
    b = @load['ref'].gsub('refs/heads/', '')

    # The SHA of the new commit.
    sha = @load['after']

    # The wannabe PR number.
    @pr = 0

    # Runs through the pull requests to find one where the HEAD matches this commit's SHA.
    gh.pull_requests.list(@user, @repo).body.each do |pr|
      @pr = pr.number if pr.head.sha == sha
    end
  # A pull request was opened.
  elsif @load['pull_request'] && @load['action'] == "opened"
    request = @load['pull_request']
    # The repository that this PR is coming from.
    a = request['head']['repo']['full_name'] + '.git'
    # The branch that this PR is coming from.
    b = request['head']['ref']
    # The HEAD SHA to use.
    sha = request['head']['sha']

    @pr = @load['number']
  end

  # Don't even bother unless there's  PR number.  We don't want to comment on every commit!
  if @pr > 0
    results = `cd ./test && sh pull.sh #{a} #{b}`
    report = JSON.parse(results)

    # Hooks into the GitHub API.  Used below.
    reporter = gh.pull_requests
    status = gh.repos.statuses

    changed_files = reporter.files(@user, @repo, @pr).map(&:filename)
    existing_comments = reporter.comments.list(@user, @repo, request_id: @pr).body.map { |i| "#{i.path}:#{i.position}:#{i.body}" }

    # Run through the files and comment on them, then leave a state.
    report['files'].each do |file, smell|
      # Remove the relative URL to this directory.
      file = file.gsub(Dir.getwd + "/test/dosomething/", '')
      if changed_files.include?(file)
        if smell['errors'] > 0 || smell['warnings'] > 0
          # Leave PR comment on specified line.
          smell['messages'].each do |message|
            unless existing_comments.include?("#{file}:#{message['line']}:#{message['message']}")
              reporter.comments.create @user, @repo, @pr, body: "#{message['message']}", commit_id: sha, path: file, position: message['line']
            end
          end
          # Leave a status update.
          status.create @user, @repo, sha, :state => "error", :description => "CodeSniffer found errors in this code."
        else
          # Leave a successful status update.
          status.crate @user, @repo, sha, :state => "success", :description => "CodeSniffer tests passed."
        end
      end
    end
  end
end
