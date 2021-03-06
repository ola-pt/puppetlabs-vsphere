# frozen_string_literal: true

# Copyright (c) 2012 Ooyala, Inc.
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Retries class
class Retries
  # default value 1.0.0
  VERSION = '1.0.0'
  class << self
    # You can use this to turn off all sleeping in with_retries. This can be useful in tests. Defaults to
    # `true`.
    attr_accessor :sleep_enabled
  end
end

Retries.sleep_enabled = true

# Module Kernel
module Kernel
  # Runs the supplied code block an retries with an exponential backoff.
  #
  # @param [Hash] options the retry options.
  # @option options [Fixnum] :max_tries (3) The maximum number of times to run the block.
  # @option options [Float] :base_sleep_seconds (0.5) The starting delay between retries.
  # @option options [Float] :max_sleep_seconds (1.0) The maximum to which to expand the delay between retries.
  # @option options [Proc] :handler (nil) If not `nil`, a `Proc` that will be called for each retry. It will be
  #         passed three arguments, `exception` (the rescued exception), `attempt_number`,
  #         and `total_delay` (seconds since start of first attempt).
  # @option options [Exception, <Exception>] :rescue (StandardError) This may be a specific exception class to
  #         rescue or an array of classes.
  # @yield [attempt_number] The (required) block to be executed, which is passed the attempt number as a
  #         parameter.
  def with_retries(options = {})
    # Check the options and set defaults
    options_error_string = 'Error with options to with_retries:'
    max_tries = options[:max_tries] || 3
    raise "#{options_error_string} :max_tries must be greater than 0." unless max_tries > 0
    base_sleep_seconds = options[:base_sleep_seconds] || 0.5
    max_sleep_seconds = options[:max_sleep_seconds] || 1.0
    if base_sleep_seconds > max_sleep_seconds
      raise "#{options_error_string} :base_sleep_seconds cannot be greater than :max_sleep_seconds."
    end
    handler = options[:handler]
    exception_types_to_rescue = Array(options[:rescue] || StandardError)
    raise "#{options_error_string} with_retries must be passed a block" unless block_given?

    # Let's do this thing
    attempts = 0
    start_time = Time.now
    begin
      attempts += 1
      return yield(attempts)
    rescue *exception_types_to_rescue => exception
      raise exception if attempts >= max_tries
      handler&.call(exception, attempts, Time.now - start_time)
      # Don't sleep at all if sleeping is disabled (used in testing).
      if Retries.sleep_enabled
        # The sleep time is an exponentially-increasing function of base_sleep_seconds. But, it never exceeds
        # max_sleep_seconds.
        sleep_seconds = [base_sleep_seconds * (2**(attempts - 1)), max_sleep_seconds].min
        # Randomize to a random value in the range sleep_seconds/2 .. sleep_seconds
        sleep_seconds *= (0.5 * (1 + rand))
        # But never sleep less than base_sleep_seconds
        sleep_seconds = [base_sleep_seconds, sleep_seconds].max
        sleep sleep_seconds
      end
      retry
    end
  end
end
