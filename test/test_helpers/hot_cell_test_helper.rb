module HotCellTestHelper
  BOOT_TIMEOUT = 30

  def self.ensure_cell_running
    return if cell_answering?

    owner = Process.pid
    log = Rails.root.join("log/hotcell-test.log").to_s
    pid = Process.spawn(Rails.root.join("bin/hotcell").to_s, out: log, err: log, pgroup: true)
    at_exit { stop_cell(pid) if Process.pid == owner }

    wait_for_cell(pid, log)
  end

  def self.cell_answering?
    HotCell.cell("active_storage").diagnose.dig(:describe, :ok)
  end

  def self.wait_for_cell(pid, log)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + BOOT_TIMEOUT
    until cell_answering?
      raise "bin/hotcell exited before it answered; see #{log}" if Process.wait(pid, Process::WNOHANG)
      raise "bin/hotcell did not answer within #{BOOT_TIMEOUT}s; see #{log}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.1
    end
  end

  def self.stop_cell(pid)
    Process.kill("TERM", -pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  private_class_method :cell_answering?, :wait_for_cell, :stop_cell
end

HotCellTestHelper.ensure_cell_running
