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
    buf/buf: declare c-string!
    buf/buflen: 0
    buf/inlen: 0
    buf
]

read-input: func [
    buf [InputBuffer!]
    /local 
        bytes [byte-ptr!]
        i
][
    bytes: fgets 
        as byte-ptr! buf/buf 
        MAX_COMMAND_SIZE
        std-in

    if bytes = NULL [
        print "^/Error reading input^/"
        quit EXIT_FAILURE
    ]

    ; 去掉末尾的换行符
    printf ["read-input len: %d, size: %d^/" (length? buf/buf) (size? buf/buf)]
    i: 0
    while [i < (length? buf/buf)][
        buf/buf/i: bytes/i
        i: i + 1
    ]
    buf/buf/i: null-byte
    printf ["read-input len: %d, size: %d^/" (length? buf/buf) (size? buf/buf)]
]

main: func [
    /local
        buf [InputBuffer!]
        ret [integer!]
][
    buf: declare InputBuffer!
    buf: new-input-buffer

    forever [
        print "db > "
        read-input buf

        ; fgets 会包含换行符
        ret: strcmp buf/buf ".exit^/"
        if zero? ret [
            quit EXIT_SUCCESS
        ]

        printf ["Unrecognized command '%s'.^/" buf/buf]
    ]
]

main


