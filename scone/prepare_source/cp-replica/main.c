#include <dirent.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>

void copy_file(char* source_path, char* target_path);
void copy_directory(char* source_path, char* target_path);

int main(int argc, char** argv)
{
    copy_directory("/data_model", "/data_mongo");
}

void copy_file(char* source_path, char* target_path)
{
    //printf("Copying file %s to %s\n", source_path, target_path);
    FILE* fptr1 = fopen(source_path, "r");
    if (fptr1 == NULL)
    {
        return;
    }

    FILE* fptr2 = fopen(target_path, "w");
    if (fptr2 == NULL)
    {
        fclose(fptr1);
        return;
    }

    while (1)
    {
        char ch = fgetc(fptr1);
        if (ch == EOF)
        {
            break;
        }

        fputc(ch, fptr2);
    }

    fclose(fptr1);
    fclose(fptr2);
}

void copy_directory(char* source_path, char* target_path)
{
    //printf("Copying folder %s to %s\n", source_path, target_path);
    DIR* base_dir;
    base_dir = opendir(source_path);
    if (base_dir != NULL)
    {
        // cria a pasta de destino.
        mkdir(target_path, S_IRWXU | S_IRWXG | S_IRWXO);

        // itera pelos filhos da pasta de origem.
        while (1)
        {
            struct dirent* dir_entry;
            dir_entry = readdir(base_dir);
            if (dir_entry == NULL) break;

            // ignora se for . ou ..
            if (strcmp(dir_entry->d_name, ".") == 0)
            {
                continue;
            }
            if (strcmp(dir_entry->d_name, "..") == 0)
            {
                continue;
            }

            // determina se o filho é pasta ou arquivo.
            char source_sub_path[256];
            sprintf(source_sub_path, "%s/%s", source_path, dir_entry->d_name);
            struct stat s;
            if (stat(source_sub_path, &s) == 0)
            {
                char target_sub_path[256];
                sprintf(target_sub_path, "%s/%s", target_path, dir_entry->d_name);

                if (s.st_mode & S_IFDIR)
                {
                    //printf("The data at %s is a folder!\n", source_sub_path);
                    // filho é pasta.
                    copy_directory(source_sub_path, target_sub_path);
                }
                else if (s.st_mode & S_IFREG)
                {
                    //printf("The data at %s is a file!\n", source_sub_path);
                    // filho é arquivo.
                    copy_file(source_sub_path, target_sub_path);
                }
            }
        }
        closedir(base_dir);
    }
}
