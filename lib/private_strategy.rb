# frozen_string_literal: true

# Custom download strategy for GitHub Private Repository releases.
# Based on the removed GitHubPrivateRepositoryReleaseDownloadStrategy from Homebrew.
#
# Usage:
#   1. Set HOMEBREW_GITHUB_API_TOKEN environment variable
#   2. In your formula, add:
#      require_relative "lib/private_strategy"
#      url "https://github.com/owner/repo/releases/download/tag/file", using: GitHubPrivateRepositoryReleaseDownloadStrategy
#
# Original source: https://github.com/Homebrew/brew (BSD 2-Clause License)
# With fixes from: https://gist.github.com/ZPascal/b21c652b811872b3f56db9d54d61d6c6

# BSD 2-Clause License
#
# Copyright (c) 2009-present, Homebrew contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "download_strategy"

# GitHubPrivateRepositoryDownloadStrategy downloads contents from GitHub
# Private Repository. To use it, add
# `using: GitHubPrivateRepositoryDownloadStrategy` to the URL section of
# your formula. This download strategy uses GitHub access tokens (in the
# environment variables `HOMEBREW_GITHUB_API_TOKEN`) to sign the request.
class GitHubPrivateRepositoryDownloadStrategy < CurlDownloadStrategy
  require "utils/formatter"
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    unless match = url.match(%r{https://github.com/([^/]+)/([^/]+)/(\S+)})
      raise CurlDownloadStrategyError, "Invalid url pattern for GitHub Repository."
    end

    _, @owner, @repo, @filepath = *match
    @filename = File.basename(@filepath)
  end

  def download_url
    "https://#{@github_token}@github.com/#{@owner}/#{@repo}/#{@filepath}"
  end

  # Fix for https://github.com/Homebrew/brew/issues/15169
  # Bypass HEAD request that does not contain token
  def resolve_url_basename_time_file_size(url, timeout: nil)
    [download_url, resolved_basename, Time.now, 0, false]
  end

  def resolved_basename
    @filename || File.basename(@filepath || url)
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    curl_download download_url, to: temporary_path
  end

  def set_github_token
    @github_token = ENV["HOMEBREW_GITHUB_API_TOKEN"] || ENV["GITHUB_TOKEN"]
    unless @github_token
      raise CurlDownloadStrategyError, "Environmental variable HOMEBREW_GITHUB_API_TOKEN or GITHUB_TOKEN is required."
    end

    validate_github_repository_access!
  end

  def validate_github_repository_access!
    GitHub::API.open_rest("https://api.github.com/repos/#{@owner}/#{@repo}")
  rescue GitHub::HTTPNotFoundError
    message = <<~EOS
      HOMEBREW_GITHUB_API_TOKEN cannot access the repository: #{@owner}/#{@repo}
      This token may not have permission to access the repository or the url of formula may be incorrect.
    EOS
    raise CurlDownloadStrategyError, message
  end
end

# GitHubPrivateRepositoryReleaseDownloadStrategy downloads tarballs from GitHub
# Release assets. To use it, add
# `using: GitHubPrivateRepositoryReleaseDownloadStrategy` to the URL section of
# your formula. This download strategy uses GitHub access tokens (in the
# environment variables HOMEBREW_GITHUB_API_TOKEN) to sign the request.
class GitHubPrivateRepositoryReleaseDownloadStrategy < GitHubPrivateRepositoryDownloadStrategy
  def parse_url_pattern
    url_pattern = %r{https://github.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(\S+)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError, "Invalid url pattern for GitHub Release."
    end

    _, @owner, @repo, @tag, @filename = *@url.match(url_pattern)
  end

  def download_url
    "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    curl_download download_url,
                  "--header", "Accept: application/octet-stream",
                  "--header", "Authorization: token #{@github_token}",
                  to: temporary_path
  end

  def asset_id
    @asset_id ||= resolve_asset_id
  end

  def resolve_asset_id
    release_metadata = fetch_release_metadata
    assets = release_metadata["assets"].select { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset file not found." if assets.empty?

    assets.first["id"]
  end

  def fetch_release_metadata
    release_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}"
    GitHub::API.open_rest(release_url)
  end
end
