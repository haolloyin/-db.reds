Red/System []

#import [
    LIBC-file cdecl [
        fgets: "fgets" [
            str         [byte-ptr!]
            count       [integer!]
            stream      [byte-ptr!]
            return:     [byte-ptr!]
        ]
        strcmp: "strcmp" [
            str1 [c-string!]
            str2 [c-string!]
            return: [integer!]
        ]
    ]
]
#either OS = 'Windows [
    #import [
        LIBC-file cdecl [
            fgets: "fgets" [
                str         [byte-ptr!]
                count       [integer!]
                stream      [byte-ptr!]
                return:     [byte-ptr!]
            ]
            fdopen: "_fdopen" [
                fd      [integer!]
                mode    [byte-ptr!]
                return: [byte-ptr!]
            ]
        ]
    ]
][
    #import [
        LIBC-file cdecl [
            fdopen: "fdopen" [
                fd      [integer!]
                mode    [byte-ptr!]
                return: [byte-ptr!]
            ]
        ]
    ]
]

std-in: fdopen 0 as byte-ptr! "r"
print-line ["std-in: " std-in]

#define MAX_COMMAND_SIZE 1024

#enum Status! [
    EXIT_SUCCESS: 0
    EXIT_FAILURE
]

InputBuffer!: alias struct! [
    buf [c-string!]
    buflen [integer!]
    inlen [integer!]
]

new-input-buffer: func [
    return: [InputBuffer! value]
    /local buf
][
    buf: declare InputBuffer!
    buf: as InputBuffer! allocate size? InputBuffer!
    buf/buf: null
    printf ["buf: %d^/" buf]
    buf/buflen: 0
    buf/inlen: 0
    buf
]

print-prompt: does [print "db > "]

read-input: func [
    buf [InputBuffer!]
    /local 
        bytes [byte-ptr!]
][
    print "111"
    bytes: fgets 
        as byte-ptr! buf/buf 
        MAX_COMMAND_SIZE
        std-in

    print "222"

    if bytes = NULL [
        print "Error reading input^/"
        quit EXIT_FAILURE
    ]
]

main: func [
    /local
        buf [InputBuffer!]
][
    buf: new-input-buffer
    forever [
        print-prompt
        read-input buf

        if zero? strcmp buf/buf ".exit" [
            quit EXIT_SUCCESS
        ]

        printf ["Unrecognized command '%s'.^/" buf/buf]
    ]
]

main


