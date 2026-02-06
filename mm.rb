# typed: false
# frozen_string_literal: true

class Mm < Formula
  desc "Personal knowledge management CLI tool (PKOS - GTD, Bullet Journal, Zettelkasten)"
  homepage "https://github.com/kecbigmt/mm"
  head "https://github.com/kecbigmt/mm.git", branch: "main"
  license "AGPL-3.0"

  depends_on "deno" => :build

  def install
    system "deno", "compile",
      "--config=deno.json",
      "--allow-read", "--allow-write", "--allow-env", "--allow-run", "--allow-sys",
      "--output=mm",
      "src/main.ts"
    bin.install "mm"
  end

  test do
    assert_match "Personal Knowledge", shell_output("#{bin}/mm --help", 1).strip
  end
end
