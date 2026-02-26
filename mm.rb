# typed: false
# frozen_string_literal: true

require_relative "lib/private_strategy"

class Mm < Formula
  desc "Personal knowledge management CLI tool (PKOS - GTD, Bullet Journal, Zettelkasten)"
  homepage "https://github.com/kkato1030/mm"
  version "0.1.4"
  license "AGPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/kkato1030/mm/releases/download/v0.1.4/mm-0.1.4-darwin-arm64",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "2348f0c94d0a7fbb6c0f384be4201a70153254a3e7e18320f6853282adeefd4d"

      def install
        bin.install "mm-0.1.4-darwin-arm64" => "mm"
      end
    end
  end

  test do
    assert_match "Personal Knowledge", shell_output("#{bin}/mm --help", 1).strip
  end
end
