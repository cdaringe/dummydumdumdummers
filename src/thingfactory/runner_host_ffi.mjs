// JavaScript FFI for runner host
// Detects available CPU cores for worker pool sizing

import os from "os";

export function get_cpu_count() {
  return os.cpus().length;
}
