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
        sscanf: "sscanf" [
            [variadic]
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
    PREPARE_SYNTAX_ERROR
]

#enum StatementType! [
    STATEMENT_INSERT
    STATEMENT_SELECT
]

row!: alias struct! [
    id [integer!]
    username [c-string!]
    email [c-string!]
]

statement!: alias struct! [
    type [StatementType!]
    row2insert [row!]
]

#define COLUMN_USERNAME_SIZE    32
#define COLUMN_EMAIL_SIZE       255
#define ID_SIZE                 4
#define USERNAME_SIZE           32
#define EMAIL_SIZE              255
#define ID_OFFSET               0
#define USERNAME_OFFSET         [ID_OFFSET + ID_SIZE]
#define EMAIL_OFFSET            [USERNAME_OFFSET + USERNAME_SIZE]
#define ROW_SIZE                [ID_SIZE + USERNAME_SIZE + EMAIL_SIZE]

serialize-row: func [
    src [row!]
    dst [byte-ptr!]
    /local tmp
][
    tmp: as byte-ptr! src
    copy-memory (dst + ID_OFFSET) (tmp + ID_OFFSET) ID_SIZE
    copy-memory (dst + USERNAME_OFFSET) (tmp + USERNAME_OFFSET) USERNAME_SIZE
    copy-memory (dst + EMAIL_OFFSET) (tmp + EMAIL_OFFSET) EMAIL_SIZE
]

deserialize-row: func [
    src [byte-ptr!]
    dst [row!]
    /local tmp
][
    tmp: as byte-ptr! dst
    copy-memory (tmp + ID_OFFSET) (src + ID_OFFSET) ID_SIZE
    copy-memory (tmp + USERNAME_OFFSET) (src + USERNAME_OFFSET) USERNAME_SIZE
    copy-memory (tmp + EMAIL_OFFSET) (src + EMAIL_OFFSET) EMAIL_SIZE
]

prepare-statement: func [
    buf [InputBuffer!]
    stmt [statement!]
    return: [PrepareResult!]
    /local
        args-assigned [integer!]
        id [integer!]
][
    if zero? strncmp buf/buf "insert" 6 [
        stmt/type: STATEMENT_INSERT
        id: 0
        args-assigned: sscanf [
            buf/buf "insert %d %s %s"
            :id                     ; 应该传入指针
            ;stmt/row2insert/id
            stmt/row2insert/username
            stmt/row2insert/email]

        if args-assigned < 3 [
            return PREPARE_SYNTAX_ERROR
        ]
        stmt/row2insert/id: id

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
    stmt/row2insert: declare row!
    stmt/row2insert/username: declare c-string!
    stmt/row2insert/email: declare c-string!

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


