using System;

namespace SasJobs.Messages
{
    [Serializable]
    public enum StatusCode
    {
        Undefined = 0,
        Running = 1,
        Done = 2,
        Aborted = 3
    }
}
