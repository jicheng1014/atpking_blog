#!/usr/bin/env ruby
require "openssl"
require "psych"
require "zlib"
require "fiddle"
require "sqlite3"
require "bcrypt"
require "puma"
require "redcarpet"
require "vips"
require "bootsnap"

abort "Unexpected Ruby" unless RUBY_VERSION == "4.0.9"
abort "BCrypt failed" unless BCrypt::Password.create("runtime-check") == "runtime-check"
db = SQLite3::Database.new(":memory:")
abort "SQLite failed" unless db.get_first_value("SELECT 1") == 1
puts "Ruby #{RUBY_VERSION}; OpenSSL #{OpenSSL::OPENSSL_LIBRARY_VERSION}; libvips #{Vips::version_string}; native gems OK"
