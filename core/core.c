#include <signal.h>
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

volatile sig_atomic_t running = 1;
void handle_signal(int sig) { running = 0; }

typedef struct {
  long mem_total;
  long mem_available;
  long mem_free;
  long cpu_user;
  long cpu_nice;
  long cpu_system;
  long cpu_idle;
  long cpu_iowait;
  long cpu_irq;
  long cpu_softirq;
} Metrics;

int read_config() {
  FILE *f = fopen("/etc/servalert/config.conf", "r");
  if (f == NULL)
    return 10; // default 10s if no config

  char line[256];
  int interval = 10;

  while (fgets(line, sizeof(line), f) != NULL) {
    if (sscanf(line, "MONITOR_INTERVAL=%d", &interval) == 1)
      break;
  }
  fclose(f);
  return interval;
}

void read_memory(Metrics *m) {

  FILE *f = fopen("/proc/meminfo", "r");
  if (f == NULL) {
    perror("fopen");
    return;
  }

  char line[256];

  while (fgets(line, sizeof(line), f) != NULL) {
    if (sscanf(line, "MemTotal: %ld kB", &m->mem_total))
      continue;
    if (sscanf(line, "MemFree: %ld kB", &m->mem_free))
      continue;
    if (sscanf(line, "MemAvailable: %ld kB", &m->mem_available))
      continue;
  }

  fclose(f);
}

void read_cpu(Metrics *m) {

  FILE *f = fopen("/proc/stat", "r");
  if (f == NULL) {
    perror("fopen");
    return;
  }

  char line[256];

  while (fgets(line, sizeof(line), f) != NULL) {
    if (sscanf(line, "cpu %ld %ld %ld %ld %ld %ld %ld", &m->cpu_user,
               &m->cpu_nice, &m->cpu_system, &m->cpu_idle, &m->cpu_iowait,
               &m->cpu_irq, &m->cpu_softirq) == 7)
      break;
  }

  fclose(f);
}

void save_metrics(sqlite3 *db, Metrics *m, double cpu_usage) {

  const char *insert =
      "INSERT INTO metrics (timestamp, cpu_percent, mem_total, mem_available) "
      "VALUES (?,?,?,?);";

  sqlite3_stmt *stmt;

  if (sqlite3_prepare_v2(db, insert, -1, &stmt, NULL) != SQLITE_OK) {
    fprintf(stderr, "Prepare failed: %s\n", sqlite3_errmsg(db));
    return;
  };

  sqlite3_bind_int64(stmt, 1, time(NULL));
  sqlite3_bind_double(stmt, 2, cpu_usage);
  sqlite3_bind_int64(stmt, 3, m->mem_total);
  sqlite3_bind_int64(stmt, 4, m->mem_available);

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    fprintf(stderr, "Insert failed: %s\n", sqlite3_errmsg(db));
  }

  sqlite3_finalize(stmt);
}

void daemonize() {
  pid_t pid = fork();
  if (pid < 0)
    exit(1);
  if (pid > 0)
    exit(0);

  if (setsid() < 0)
    exit(1);

  close(STDIN_FILENO);
  close(STDOUT_FILENO);
  close(STDERR_FILENO);
}

int main(int argc, char *argv[]) {

  daemonize();

  sqlite3 *db;
  if (sqlite3_open("/var/lib/servalert/metrics.db", &db) != SQLITE_OK) {
    exit(1);
  }

  // create table once
  char *err = NULL;
  const char *sql = "CREATE TABLE IF NOT EXISTS metrics ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                    "timestamp INTEGER,"
                    "cpu_percent REAL,"
                    "mem_total INTEGER,"
                    "mem_available INTEGER);";
  sqlite3_exec(db, sql, NULL, NULL, &err);

  Metrics prev = {0};
  Metrics curr = {0};

  // first read — no delta yet
  read_cpu(&prev);
  read_memory(&prev);

  int interval = read_config();
  struct timespec ts = {interval, 0};

  signal(SIGTERM, handle_signal);
  signal(SIGINT, handle_signal);

  while (running) {
    nanosleep(&ts, NULL);

    read_cpu(&curr);
    read_memory(&curr);

    long prev_total = prev.cpu_user + prev.cpu_nice + prev.cpu_system +
                      prev.cpu_idle + prev.cpu_iowait + prev.cpu_irq +
                      prev.cpu_softirq;
    long curr_total = curr.cpu_user + curr.cpu_nice + curr.cpu_system +
                      curr.cpu_idle + curr.cpu_iowait + curr.cpu_irq +
                      curr.cpu_softirq;
    long prev_idle = prev.cpu_idle + prev.cpu_iowait;
    long curr_idle = curr.cpu_idle + curr.cpu_iowait;

    long delta_total = curr_total - prev_total;
    long delta_idle = curr_idle - prev_idle;

    double cpu_percent = (double)(delta_total - delta_idle) / delta_total * 100;

    save_metrics(db, &curr, cpu_percent);

    prev = curr;
  }

  sqlite3_close(db);
  return 0;
}
