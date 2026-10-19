// Exercise the actual IndexArray template with the actual allocator implementation.
#include "Core/Rtt_Build.h"
#include "Core/Rtt_StringHash.h"
#include <cstring>

template<typename T> int CheckArray()
{
    Rtt_Allocator* allocator = Rtt_AllocatorCreate();
    if (!allocator) return 1;
    int result = 0;
    {
        Rtt::IndexArray<T> values(*allocator);
        values.Reserve(4, static_cast<T>(85));
        if (values.Length() != 4 || values[0] != 85 || values[3] != 85) result = 2;
    }
    Rtt_AllocatorDestroy(allocator);
    return result;
}

int main(int argc, char** argv)
{
    if (argc != 2) return 3;
    if (std::strcmp(argv[1], "uint32") == 0) return CheckArray<unsigned int>();
    if (std::strcmp(argv[1], "uint16") == 0) return CheckArray<unsigned short>();
    return 4;
}
