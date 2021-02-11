#include "hdf5.h"
#include<stdlib.h>

int whatisopen(hid_t fid) {
        ssize_t cnt;
        int howmany;
        int i;
        H5I_type_t ot;
        hid_t anobj;
        hid_t *objs;
        char name[1024];
        herr_t status;

        cnt = H5Fget_obj_count(fid, H5F_OBJ_ALL);

        if (cnt <= 0) return cnt;

        printf("%d object(s) open\n", cnt);

        objs = malloc(cnt * sizeof(hid_t));

        howmany = H5Fget_obj_ids(fid, H5F_OBJ_ALL, cnt, objs);

        printf("open objects:\n");

        for (i = 0; i < howmany; i++ ) {
             anobj = *objs++;
             ot = H5Iget_type(anobj);
             status = H5Iget_name(anobj, name, 1024);
             printf(" %d: type %d, name %s\n",i,ot,name);
        }
         
        return howmany;
}
