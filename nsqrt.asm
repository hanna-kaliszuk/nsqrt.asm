; HANNA KALISZUK "nsqrt"
;
; Funkcja wołana z C o następującej deklaracji: void nsqrt(uint64_t *Q, uint64_t *X, unsigned n)
;
; Parametry Q i X są wskaźnikami na binarną reprezentację odpowiednio liczb Q i X, gdzie X jest 2n-bitową, nieujemną
; liczbą całkowitą, a Q n-bitową liczbą całkowitą taką, że Q^2 <= X < (Q + 1)^2. Parametr n zawiera liczbę bitów i jest
; to liczba podzielna przez 64 z przedziału 64-256000.
;
; **SPOSÓB WYZNACZANIA PIERWIASTKA**
; Początkowo Q_0 = 0, R_0 = X. Po j-tej iteracji ustawiony zostaje q_j bit wyniku. Zgodnie z założeniami zadania
; T_j-1 = 2^(n - j + 1) * Q_j-1 + 4^(n - j) dla j z przedziału {1, ..., n}.
;
; Zauważmy jednak, że dla dowolnego j z podanego przedziału, Q_j-1 będzie miało długość j-1 bitów (mniej znaczące bity
; będą zerami, ponieważ jeszcze nie zostały ustawione na żadną z wartości). Pomnożenie Q_j-1 przez 2^(n - j + 1)
; zmieni jedynie "moc" bitów, a nie długość całego Q.
;
; Dodanie 4^(n - j) odpowiada dodanie jedynki na 2n - 2j  pozycji w przesuniętym Q (= T), zatem na pozycji
; (n - j - 1) + (n - j + 1) = 2n - 2n w T, czyli na pierwszym jeszcze nie ustawionym bicie. Widać teraz, że długość
; T <= n, zatem dodatkowa pamięć do przechowywania wartości T nie jest konieczna, a co więcej możemy obliczać wartości
; poszczególnych bitów "w locie".
;
; Następnie porównujemy wartości R (trzymana w X) i T (odpowiednio obliczana w locie), porównując równolegle bity w
; kolejności od najstarszego do najmłodszego. Gdy R >= T j-ty bit w Q zostaje ustawiony na 1, a R_j = R_j-1 - T_j-1.
; Odejmowanie będzie wykonywane bit po bicie, zaczynając od najmłodszego i uwzględniając ewentualne pożyczki ze
; starszych. Jeżeli R < T, q_j = 0, a R_j = R_j-1.
;
; W przypadku, gdy do funkcji zostanie przekazany wskaźnik, który jest nullem lub n, tże n % 64 != 0, funkcja nie wykona
; żadnej operacji.
;
; **OGÓLNY ALGORYTM**
; Program rozpoczyna się od sprawdzenia warunków koniecznych do poprawnej realizacji algorytmu (wskaźniki != null,
; n % 64 = 0). Następnie czyści Q, ustawiając jego wartość na 0.
; Główna pętla - ITERATE odpowiada za wykonanie dokładnie n iteracji i wyliczenie Q_j dla każdego j.
; Pętla wewnętrzna - COMPARE odpowiada za porównywanie bit po bicie i przekazanie wyniku dalej.
; Pętla odejmująca - SUBTRACT odpowiada za wyliczenie nowego R = odejmowanie od R, T

section .data
    MASK_63 equ 0x3F                ; maska na 64 bitowe wyrównanie

section .text
    global  nsqrt

%macro CLEAR_Q 0
    push    rdi

    ; oblicz liczbę słów w Q wiedząc, że n > 0 i n % 64 =0
    mov     ecx, edx
    shr     ecx, 6                  ; word_num = n / 64

    xor     rax, rax
    rep     stosq                   ; czyść każde słowo w Q

    pop     rdi
%endmacro

; makro do odczytywania wartości bitu na pozycji %1 w R (= X)
; modyfikuje: r11, r13, ecx
; przekazuje wynik w r11
%macro CALCULATE_R_BIT 1
    mov     r11d, %1                ; word_id = iterator
    shr     r11d, 6                 ; word_id = iterator / 64

    mov     ecx, %1                 ; bit_position = iterator
    and     ecx, MASK_63            ; bit_position = iterator % 64

    mov     r13, [rsi + r11*8]      ; załaduj X[word_id]
    bt      r13, rcx                ; sprawdź wartość bitu X[word_id][bit_pos]
    setc    r11b                    ; ustaw r_bit
%endmacro


; makro do obliczania wartości t_bitu na pozycji %1 w locie zgodnie z początkowym opisem
; modyfikuje: ecx, r10, r15
; przekazuje wynik w r10
%macro CALCULATE_T_BIT 1
    ; oblicz first_uninitialized = 2n - 2j
    mov     ecx, edx
    sub     ecx, r8d
    shl     ecx, 1                  ; first_uninitialized = 2n - 2j

    cmp     %1, ecx
    je      %%t_bit_one             ; if (iterator == first_uninitialized) t_bit = 1
    jb      %%t_bit_zero            ; if (iterator < first_uninitialized) t_bit = 0

    ; wpp sprawdź czy iterator <= 2n - j (czy w "oknie ustawionych bitów")
    add     ecx, r8d                ; condition = 2n - j
    cmp     %1, ecx

    ja      %%t_bit_zero            ; if (iterator > condition) t_bit = 0

    ; oblicz shift = n - j + 1
    lea     ecx, [edx + 1]          ; shift = n + 1
    sub     ecx, r8d                ; shift = n - j + 1

    ; oblicz q_index = iterator - shift
    mov     r10d, %1
    sub     r10d, ecx               ; q_index = iterator - shift

    ; oblicz word_id i bit_position
    mov     ecx, r10d               ; q_index
    shr     r10d, 6                 ; word_id = q_index / 64
    and     ecx, MASK_63            ; bit_position = q_index % 64

    ; wylicz t_bit
    mov     r15, [rdi + r10*8]      ; załaduj Q[word_id]
    bt      r15, rcx                ; sprawdź wartość bitu
    setc    r10b                    ; ustaw t_bit
    jmp     %%t_bit_set

%%t_bit_one:
    mov     r10d, 1                 ; t_bit = 1
    jmp     %%t_bit_set

%%t_bit_zero:
    xor     r10d, r10d              ; t_bit = 0
%%t_bit_set:
%endmacro

; ITERATE: odpowiada za wykonanie n iteracji. W każdej z nich obliczane jest przesunięcie: shift = n - j + 1,
; first_uninitialized = 2n - 2j oraz inicjalizowana zmienna comp, zgodnie z opisanym powyżej założeniem. W każdej
; iteracji wykonywana jest także pętla COMPARE, której działanie zostanie opisane poniżej. Po zakończeniu wewnętrznej
; pętli, w zależności od wartości zmiennej comp, wykonywane jest odejmowanie przy użyciu pętli SUBTRACt.
; modyfikuje: r8, r9 oraz rejestry modyfikowane przez makra
%macro ITERATE 0
    mov     r8d, 1                  ; j = 1
%%iterate:
    cmp     r8d, edx                ; while (j <= n)
    ja      %%iterate_end

    ; zainicjalizuj zmienną do trzymania wyniku porównania: comp =
    ;       2 if R = T
    ;       1 if R > T
    ;       0 if R < T
    ; początkowo zakładając równość
    mov     r9d, 2                  ; comp = 2

    COMPARE

    test    r9d, r9d
    jz      %%continue_iterating    ; if (comp == 0) kontynuuj ITERATE

    ; else -> odejmij
    SUBTRACT

%%continue_iterating:
    inc     r8d                     ; j++
    jmp     %%iterate

%%iterate_end:
%endmacro

; COMPARE: pętla odpowiedzialna za porównanie R i T poprzez równoczesne porównywanie bitów, od najbardziej do
; najmniej znaczących. Wykonuje się dopóki i > 0 lub nie zajdzie nierówność (R > T lub R < T). Wartość zmiennej comp
; jest odpowiednio aktualizowana w każdym z przypadków. Wykorzystywane jest obliczanie wartości t_bit w "locie" zgodnie
; z opisanymi na początku założeniami.
; modyfikuje: eax, r9, r11, r12, r14 oraz rejestry modyfikowane przez makra
%macro COMPARE 0
    ; inicjalizacja licznika
    lea     eax, [edx * 2 - 1]      ; i = 2n - 1
%%compare:
    test    eax, eax                ; while (i >= 0)
    js      %%compare_end

    CALCULATE_T_BIT eax
    CALCULATE_R_BIT eax

    ; porównaj r_bit i t_bit
    cmp     r11b, r10b
    jg      %%r_greater
    jl      %%t_greater

    ; r_bit == t_bit: kontynuujemy pętlę
    dec     eax
    jmp     %%compare

%%r_greater:
    mov     r9d, 1                  ; comp = 1 (R > T)
    jmp     %%compare_end           ; break

%%t_greater:
    xor     r9d, r9d                ; comp = 0 (R < T)
%%compare_end:
%endmacro

; SUBTRACT: pętla odpowiedzialna za wykonanie odejmowania z pożyczeniem, a także odpowiednie ustawienie bitu w X (R).
; Podobnie jak COMPARE oblicza wartości t_bit w "locie" zgodnie z początkowymi założeniami. Dodatkowo weryfikuje, czy
; bit, który należy ustawić znajduje się w przedziale ustawionych już bitów ((first_uninitialized, 2n - j]). Jeżeli tak,
; wartość bitu będzie zależała od wartości odpowiadającego bitu w Q. Wpp zostanie ona wyliczona poprzez odejmowanie.
; modyfikuje: eax, r9, r11, r12, r14 oraz rejestry modyfikowane przez makra
%macro SUBTRACT 0
    xor     r14d, r14d              ; borrow = 0
    xor     eax, eax                ; k = 0
    mov     r9d, edx                ; loop limit = n
    shl     r9d, 1                  ; loop limit = 2n

%%subtract:
    cmp     eax, r9d                ; while (k < 2n)
    jge     %%subtract_end

    CALCULATE_T_BIT eax
    CALCULATE_R_BIT eax

    ; oblicz diff = r_bit - t_bit - borrow
    sub     r11d, r10d              ; diff = r_bit - t_bit
    sub     r11d, r14d              ; diff = r_bit - t_bit - borrow

    ; obsłuż brak pożyczki
    jge     %%no_borrow             ; if (diff >= 0) borrow = 0

    ; obsłuż pożyczkę
    add     r11d, 2                 ; diff += 2
    mov     r14d, 1                 ; borrow = 1
    jmp     %%update_bit

%%no_borrow:
    xor     r14d, r14d              ; borrow = 0

%%update_bit:
    mov     r12d, eax               ; word_id = k
    shr     r12d, 6                 ; word_id = k / 64
    lea     r12, [rsi + r12*8]      ; załaduj X[word_id]

    ; ustaw bit na pozycji k w X (= R) na wartość diff
    test    r11d, r11d
    jz      %%clear_bit             ; if (diff == 0) ustaw na 0

    bts     [r12], rcx              ; else -> ustaw na 1
    jmp     %%next

%%clear_bit:
    btr     [r12], rcx              ; ustaw na 0

%%next:
    inc     eax                     ; k++
    jmp     %%subtract

%%subtract_end:
    ; wiemy, że jeżeli weszliśmy do pętli k to ustawiamy odpowiedni bit w Q na 1 (bo była relacja R >= T)

    ; set_bit (Q, n - j, q)
    mov     r12d, edx                       ; bit_position = n
    sub     r12d, r8d                       ; bit_position = n - j

    mov     r11d, r12d                      ; word_id = bit_position
    shr     r11d, 6                         ; word_id = bit_position / 64

    and     r12d, MASK_63                   ; bit_pos = bit_position % 64

    bts     [rdi + r11*8], r12              ; ustawiamy bit na 1

    ; wiemy, że jeżeli nie weszliśmy do pętli, to bit należy ustawić na 0. Ale ponieważ początkowo Q = 0, to  0 już tam
    ; są, w związku z czym nie musimy nic dodatkowo ustawiać
%endmacro

nsqrt:
    push    r12
    push    r13
    push    r14
    push    r15

    CLEAR_Q

    ITERATE

.nsqrt_end:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret