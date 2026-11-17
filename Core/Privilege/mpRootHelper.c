#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <spawn.h>
#include <sys/stat.h>
#include <sys/wait.h>

extern char **environ;

static int is_system_root_path(const char *path) {
    if (!path) return 1;
    const char *forbidden[] = {
        "/", "/var", "/var/mobile", "/var/jb", "/private", "/System", "/Library",
        "/Applications", "/usr", "/bin", "/sbin", "/etc", "/dev", "/Volumes", NULL
    };
    for (int i = 0; forbidden[i] != NULL; ++i) {
        if (strcmp(path, forbidden[i]) == 0) return 1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    setuid(0);
    setgid(0);
    seteuid(0);
    setegid(0);

    if (argc < 2) {
        return 1;
    }

    const char *action = argv[1];

    if (strcmp(action, "delete") == 0 && argc >= 3) {
        if (is_system_root_path(argv[2])) {
            return 2;
        }
        char *rm_args[] = {"rm", "-rf", argv[2], NULL};
        pid_t pid;
        if (posix_spawnp(&pid, "rm", NULL, NULL, rm_args, environ) == 0) {
            int status = 0;
            waitpid(pid, &status, 0);
            return WEXITSTATUS(status);
        }
        return 1;
    }

    if (strcmp(action, "extract") == 0 && argc >= 4) {
        char *tar_args[] = {"tar", "-xf", argv[2], "--no-same-owner", "-C", argv[3], NULL};
        pid_t pid;
        if (posix_spawnp(&pid, "tar", NULL, NULL, tar_args, environ) == 0) {
            int status = 0;
            waitpid(pid, &status, 0);
            return WEXITSTATUS(status);
        }
        return 1;
    }

    if (strcmp(action, "chmod") == 0 && argc >= 4) {
        mode_t mode = (mode_t)strtol(argv[2], NULL, 8);
        return chmod(argv[3], mode);
    }

    if (strcmp(action, "chown") == 0 && argc >= 5) {
        uid_t u = (uid_t)strtol(argv[2], NULL, 10);
        gid_t g = (gid_t)strtol(argv[3], NULL, 10);
        return chown(argv[4], u, g);
    }

    if (strcmp(action, "mkdir") == 0 && argc >= 3) {
        char *mkdir_args[] = {"mkdir", "-p", argv[2], NULL};
        pid_t pid;
        if (posix_spawnp(&pid, "mkdir", NULL, NULL, mkdir_args, environ) == 0) {
            int status = 0;
            waitpid(pid, &status, 0);
            return WEXITSTATUS(status);
        }
        return 1;
    }

    if (strcmp(action, "move") == 0 && argc >= 4) {
        char *mv_args[] = {"mv", "-f", argv[2], argv[3], NULL};
        pid_t pid;
        if (posix_spawnp(&pid, "mv", NULL, NULL, mv_args, environ) == 0) {
            int status = 0;
            waitpid(pid, &status, 0);
            return WEXITSTATUS(status);
        }
        return 1;
    }

    if (strcmp(action, "touch") == 0 && argc >= 3) {
        FILE *fp = fopen(argv[2], "a");
        if (fp) {
            fclose(fp);
            return 0;
        }
        return 1;
    }

    if (strcmp(action, "spawn") == 0 && argc >= 3) {
        pid_t pid;
        if (posix_spawnp(&pid, argv[2], NULL, NULL, &argv[2], environ) == 0) {
            int status = 0;
            waitpid(pid, &status, 0);
            return WEXITSTATUS(status);
        }
        return 1;
    }

    return 0;
}
