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
        strncmp: "strncmp" [
            str1 [c-string!]
            str2 [c-string!]
            n [integer!]
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

    i: length? buf/buf
    if bytes/i = #"^/" [
        ; fgets 会包含换行符，去掉掉末尾的换行符
        ;printf ["read-input len: %d, size: %d^/" (length? buf/buf) (size? buf/buf)]
        i: 0
        while [i < (length? buf/buf)][
            buf/buf/i: bytes/i
            i: i + 1
        ]
        buf/buf/i: null-byte
        ;printf ["read-input len: %d, size: %d^/" (length? buf/buf) (size? buf/buf)]
    ]
]

#enum MetaCommandResult! [
    META_COMMAND_SUCCESS
    META_COMMAND_UNRECOGNIZED_COMMAND
]

#enum PrepareResult! [
    PREPARE_SUCCESS
    PREPARE_UNRECOGNIZED_STATEMENT
]

#enum StatementType! [
    STATEMENT_INSERT
    STATEMENT_SELECT
]

statement!: alias struct! [
    type [StatementType!]
]

prepare-statement: func [
    buf [InputBuffer!]
    stmt [statement!]
    return: [PrepareResult!]
][
    if zero? strncmp buf/buf "insert" 6 [
        stmt/type: STATEMENT_INSERT
        return PREPARE_SUCCESS
    ]
    if zero? strcmp buf/buf "select" [
        stmt/type: STATEMENT_SELECT
        return PREPARE_SUCCESS
    ]
    PREPARE_UNRECOGNIZED_STATEMENT
]

execute-statement: func [
    stmt [statement!]
][
    ;print-line ["stmt/type: " stmt/type]
    switch stmt/type [
        STATEMENT_INSERT [
            print "This is where we would do an insert.^/^/"
        ]
        STATEMENT_SELECT [
            print "This is where we would do a select.^/^/"
        ]
    ]
]

do-meta-command: func [
    buf [InputBuffer!]
    return: [MetaCommandResult!]
][
    if any [zero? strcmp buf/buf ".exit" zero? strcmp buf/buf ".q"][
        printf "Bye~^/"
        quit EXIT_SUCCESS
    ]
    META_COMMAND_UNRECOGNIZED_COMMAND
]

main: func [
    /local
        buf [InputBuffer!]
        stmt [statement!]
][
    buf: declare InputBuffer!
    buf: new-input-buffer
    stmt: declare statement!

    forever [
        print "db > "
        read-input buf

        if buf/buf/1 = #"." [
            switch do-meta-command buf [
                META_COMMAND_SUCCESS [
                    continue
                ]
                META_COMMAND_UNRECOGNIZED_COMMAND [
                    printf ["Unrecognized command '%s'.^/^/" buf/buf]
                    continue
                ]
            ]
        ]

        switch prepare-statement buf stmt [
            PREPARE_SUCCESS [
                
            ]
            PREPARE_UNRECOGNIZED_STATEMENT [
                printf ["Unrecognized keyword at start of '%s'.^/^/" buf/buf]
                continue
            ]
        ]

        execute-statement stmt
        print "Executed.^/^/"
    ]
]

main


