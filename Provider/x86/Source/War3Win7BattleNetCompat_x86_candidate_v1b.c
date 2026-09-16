/*
 * Warcraft III / Battle.net Windows 7 x86 compatibility provider candidate v1b
 * OFFLINE BUILD CANDIDATE - do not install before independent audit.
 *
 * Architecture-specific PE32 reconstruction of the already validated x64 provider:
 *   - Win7 SSL provider slots 0..25 preserve the historical C02F compatibility semantics.
 *   - Interface version 3 appends the real ncrypt callbacks in slots 26/27.
 *   - No status is fabricated; nested ncrypt errors are returned unchanged.
 *   - Only KERNEL32 loader/heap APIs are imported, matching the historical design surface.
 */

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef int s32;
typedef unsigned int usize;
typedef void *PVOID;
typedef u16 WCHAR;

#define STDCALL __attribute__((stdcall))
#define NTE_NO_MEMORY       ((s32)0x8009000E)
#define NTE_INVALID_PARAMETER ((s32)0x80090027)
#define NTE_NOT_SUPPORTED   ((s32)0x80090029)
#define NTE_NO_MORE_ITEMS   ((s32)0x8009002A)
#define TLS12               0x00000303u
#define SUITE_C02F          0x0000C02Fu
#define SUITE_C02B          0x0000C02Bu
#define HEAP_ZERO_MEMORY    0x00000008u

/* Exact KERNEL32 import surface used by the historical provider. */
__declspec(dllimport) PVOID STDCALL GetProcAddress(PVOID hModule, const char *name);
__declspec(dllimport) PVOID STDCALL GetProcessHeap(void);
__declspec(dllimport) PVOID STDCALL HeapAlloc(PVOID hHeap, u32 flags, usize bytes);
__declspec(dllimport) int   STDCALL HeapFree(PVOID hHeap, u32 flags, PVOID mem);
__declspec(dllimport) PVOID STDCALL LoadLibraryW(const WCHAR *name);

/* Win7 NCRYPT_SSL_CIPHER_SUITE; sizeof == 0x2A4 on x86/x64. */
typedef struct _SSL_SUITE {
    u32 dwProtocol;
    u32 dwCipherSuite;
    u32 dwBaseCipherSuite;
    WCHAR szCipherSuite[64];
    WCHAR szCipher[64];
    u32 dwCipherLen;
    u32 dwCipherBlockLen;
    WCHAR szHash[64];
    u32 dwHashLen;
    WCHAR szExchange[64];
    u32 dwMinExchangeLen;
    u32 dwMaxExchangeLen;
    WCHAR szCertificate[64];
    u32 dwKeyType;
} SSL_SUITE;

/* x86 v3 geometry: DWORD version + 28 DWORD callback pointers = 0x74 bytes. */
typedef struct _SSL_TABLE_V3 {
    u32 version;
    PVOID f[28];
} SSL_TABLE_V3;

/* Custom EnumCipherSuites allocations are linked exactly so FreeBuffer can identify
 * them without dereferencing arbitrary native pointers.  On x86 the link is 4 bytes,
 * so the returned suite begins at node+4.  0x2B0 retains the historical allocation size. */
typedef struct _CUSTOM_NODE {
    struct _CUSTOM_NODE *next;
    SSL_SUITE suite;
} CUSTOM_NODE;

static PVOID g_real[28];
static SSL_TABLE_V3 g_table;
static volatile u32 g_init_lock;
static volatile u32 g_list_lock;
static int g_ready;
static CUSTOM_NODE *g_custom_head;

static const WCHAR w_ncrypt[] = {'n','c','r','y','p','t','.','d','l','l',0};
static const WCHAR w_ms_ssl[] = {'M','i','c','r','o','s','o','f','t',' ','S','S','L',' ','P','r','o','t','o','c','o','l',' ','P','r','o','v','i','d','e','r',0};
static const WCHAR w_rsa[] = {'R','S','A',0};
static const WCHAR w_name256[] = {'T','L','S','_','E','C','D','H','E','_','R','S','A','_','W','I','T','H','_','A','E','S','_','1','2','8','_','G','C','M','_','S','H','A','2','5','6','_','P','2','5','6',0};
static const WCHAR w_name384[] = {'T','L','S','_','E','C','D','H','E','_','R','S','A','_','W','I','T','H','_','A','E','S','_','1','2','8','_','G','C','M','_','S','H','A','2','5','6','_','P','3','8','4',0};
static const WCHAR w_name521[] = {'T','L','S','_','E','C','D','H','E','_','R','S','A','_','W','I','T','H','_','A','E','S','_','1','2','8','_','G','C','M','_','S','H','A','2','5','6','_','P','5','2','1',0};

static const char *const ssl_names[28] = {
    "SslComputeClientAuthHash", "SslComputeEapKeyBlock", "SslComputeFinishedHash",
    "SslCreateEphemeralKey", "SslCreateHandshakeHash", "SslDecryptPacket",
    "SslEncryptPacket", "SslEnumCipherSuites", "SslExportKey", "SslFreeBuffer",
    "SslFreeObject", "SslGenerateMasterKey", "SslGenerateSessionKeys",
    "SslGetKeyProperty", "SslGetProviderProperty", "SslHashHandshake",
    "SslImportMasterKey", "SslImportKey", "SslLookupCipherSuiteInfo",
    "SslOpenPrivateKey", "SslOpenProvider", "SslSignHash", "SslVerifySignature",
    "SslLookupCipherLengths", "SslCreateClientAuthHash",
    "SslGetCipherSuitePRFHashAlgorithm", "SslComputeSessionHash",
    "SslGeneratePreMasterKey"
};

static void spin_lock(volatile u32 *p){
    u32 v;
    do {
        v=1u;
        __asm__ volatile("xchgl %0,%1" : "+r"(v), "+m"(*p) :: "memory");
    } while(v!=0u);
}
static void spin_unlock(volatile u32 *p){
    __asm__ volatile("" ::: "memory");
    *p=0u;
}

static void wcopyz(WCHAR *dst,const WCHAR *src){
    WCHAR c;
    do { c=*src++; *dst++=c; } while(c!=0);
}

static u32 map_suite(u32 s){ return s==SUITE_C02F ? SUITE_C02B : s; }
static u32 normalize_keytype(u32 k){ return (k==23u || k==24u || k==25u) ? k : 23u; }

static void patch_suite(SSL_SUITE *s,u32 keyType){
    const WCHAR *nm;
    s->dwCipherSuite=SUITE_C02F;
    s->dwBaseCipherSuite=SUITE_C02F;
    s->dwKeyType=keyType;
    nm=(keyType==24u) ? w_name384 : ((keyType==25u) ? w_name521 : w_name256);
    wcopyz(s->szCipherSuite,nm);
    wcopyz(s->szCertificate,w_rsa);
}

static SSL_SUITE *alloc_custom_suite(void){
    CUSTOM_NODE *n;
    PVOID heap=GetProcessHeap();
    if(!heap) return (SSL_SUITE*)0;
    n=(CUSTOM_NODE*)HeapAlloc(heap,HEAP_ZERO_MEMORY,(usize)0x2B0u);
    if(!n) return (SSL_SUITE*)0;
    spin_lock(&g_list_lock);
    n->next=g_custom_head;
    g_custom_head=n;
    spin_unlock(&g_list_lock);
    return &n->suite;
}

static int free_custom_suite(PVOID p){
    CUSTOM_NODE *cur,*prev,*victim=(CUSTOM_NODE*)0;
    if(!p) return 0;
    spin_lock(&g_list_lock);
    prev=(CUSTOM_NODE*)0;
    cur=g_custom_head;
    while(cur){
        if((PVOID)&cur->suite==p){
            if(prev) prev->next=cur->next;
            else g_custom_head=cur->next;
            victim=cur;
            break;
        }
        prev=cur;
        cur=cur->next;
    }
    spin_unlock(&g_list_lock);
    if(victim){
        PVOID heap=GetProcessHeap();
        if(heap) HeapFree(heap,0u,(PVOID)victim);
        return 1;
    }
    return 0;
}

/* Exact public signatures for the historical local slots. */
typedef s32 (STDCALL *FN_CreateEphemeralKey)(PVOID,PVOID*,u32,u32,u32,u32,u8*,u32,u32);
typedef s32 (STDCALL *FN_CreateHandshakeHash)(PVOID,PVOID*,u32,u32,u32);
typedef s32 (STDCALL *FN_EnumCipherSuites)(PVOID,PVOID,SSL_SUITE**,PVOID*,u32);
typedef s32 (STDCALL *FN_FreeBuffer)(PVOID);
typedef s32 (STDCALL *FN_GenerateMasterKey)(PVOID,PVOID,PVOID,PVOID*,u32,u32,PVOID,u8*,u32,u32*,u32);
typedef s32 (STDCALL *FN_ImportMasterKey)(PVOID,PVOID,PVOID*,u32,u32,PVOID,u8*,u32,u32);
typedef s32 (STDCALL *FN_LookupCipherSuiteInfo)(PVOID,u32,u32,u32,SSL_SUITE*,u32);
typedef s32 (STDCALL *FN_OpenProvider)(PVOID*,const WCHAR*,u32);
typedef s32 (STDCALL *FN_LookupCipherLengths)(PVOID,u32,u32,u32,PVOID,u32,u32);
typedef s32 (STDCALL *FN_CreateClientAuthHash)(PVOID,PVOID*,u32,u32,const WCHAR*,u32);
typedef s32 (STDCALL *FN_GetPRF)(PVOID,u32,u32,u32,WCHAR*,u32);

static s32 STDCALL wrap_CreateEphemeralKey(PVOID h,PVOID *ph,u32 proto,u32 suite,u32 keytype,u32 bits,u8 *params,u32 cb,u32 flags){
    return ((FN_CreateEphemeralKey)g_real[3])(h,ph,proto,map_suite(suite),keytype,bits,params,cb,flags);
}
static s32 STDCALL wrap_CreateHandshakeHash(PVOID h,PVOID *ph,u32 proto,u32 suite,u32 flags){
    return ((FN_CreateHandshakeHash)g_real[4])(h,ph,proto,map_suite(suite),flags);
}
static s32 STDCALL wrap_EnumCipherSuites(PVOID h,PVOID hPrivate,SSL_SUITE **ppSuite,PVOID *ppState,u32 flags){
    u32 state,keytype;
    SSL_SUITE *s;
    s32 st;
    (void)flags;
    if(!ppSuite || !ppState) return NTE_INVALID_PARAMETER;
    *ppSuite=(SSL_SUITE*)0;
    if(hPrivate){ *ppState=(PVOID)0; return NTE_NO_MORE_ITEMS; }
    state=(u32)(usize)(*ppState);
    if(state>=3u){ *ppState=(PVOID)0; return NTE_NO_MORE_ITEMS; }
    keytype=(state==0u) ? 23u : ((state==1u) ? 24u : 25u);
    s=alloc_custom_suite();
    if(!s) return NTE_NO_MEMORY;
    /* Historical Enum always queried native C02B with reserved dwFlags=0. */
    st=((FN_LookupCipherSuiteInfo)g_real[18])(h,TLS12,SUITE_C02B,keytype,s,0u);
    if(st!=0){ free_custom_suite((PVOID)s); return st; }
    patch_suite(s,keytype);
    *ppSuite=s;
    *ppState=(PVOID)(usize)(state+1u);
    return 0;
}
static s32 STDCALL wrap_FreeBuffer(PVOID p){
    if(!p) return 0;
    if(free_custom_suite(p)) return 0;
    return ((FN_FreeBuffer)g_real[9])(p);
}
static s32 STDCALL wrap_GenerateMasterKey(PVOID h,PVOID priv,PVOID pub,PVOID *ph,u32 proto,u32 suite,PVOID params,u8 *out,u32 cb,u32 *pcb,u32 flags){
    return ((FN_GenerateMasterKey)g_real[11])(h,priv,pub,ph,proto,map_suite(suite),params,out,cb,pcb,flags);
}
static s32 STDCALL wrap_ImportMasterKey(PVOID h,PVOID priv,PVOID *ph,u32 proto,u32 suite,PVOID params,u8 *enc,u32 cb,u32 flags){
    return ((FN_ImportMasterKey)g_real[16])(h,priv,ph,proto,map_suite(suite),params,enc,cb,flags);
}
static s32 STDCALL wrap_LookupCipherSuiteInfo(PVOID h,u32 proto,u32 suite,u32 keytype,SSL_SUITE *out,u32 flags){
    s32 st;
    u32 k;
    if(suite!=SUITE_C02F) return ((FN_LookupCipherSuiteInfo)g_real[18])(h,proto,suite,keytype,out,flags);
    if(!out) return NTE_INVALID_PARAMETER;
    k=normalize_keytype(keytype);
    st=((FN_LookupCipherSuiteInfo)g_real[18])(h,proto,SUITE_C02B,k,out,flags);
    if(st==0) patch_suite(out,k);
    return st;
}
static s32 STDCALL wrap_OpenProvider(PVOID *ph,const WCHAR *name,u32 flags){
    (void)name;
    return ((FN_OpenProvider)g_real[20])(ph,w_ms_ssl,flags);
}
static s32 STDCALL wrap_LookupCipherLengths(PVOID h,u32 proto,u32 suite,u32 keytype,PVOID lengths,u32 cb,u32 flags){
    return ((FN_LookupCipherLengths)g_real[23])(h,proto,map_suite(suite),normalize_keytype(keytype),lengths,cb,flags);
}
static s32 STDCALL wrap_CreateClientAuthHash(PVOID h,PVOID *ph,u32 proto,u32 suite,const WCHAR *alg,u32 flags){
    return ((FN_CreateClientAuthHash)g_real[24])(h,ph,proto,map_suite(suite),alg,flags);
}
static s32 STDCALL wrap_GetPRF(PVOID h,u32 proto,u32 suite,u32 keytype,WCHAR *out,u32 flags){
    return ((FN_GetPRF)g_real[25])(h,proto,map_suite(suite),normalize_keytype(keytype),out,flags);
}

static int init_provider(void){
    PVOID n;
    u32 i;
    if(g_ready==1) return 1;
    spin_lock(&g_init_lock);
    if(g_ready==1){ spin_unlock(&g_init_lock); return 1; }

    n=LoadLibraryW(w_ncrypt);
    if(!n){ spin_unlock(&g_init_lock); return 0; }
    for(i=0;i<28u;i++){
        g_real[i]=GetProcAddress(n,ssl_names[i]);
        if(!g_real[i]){ spin_unlock(&g_init_lock); return 0; }
    }

    g_table.version=3u;
    for(i=0;i<28u;i++) g_table.f[i]=g_real[i];
    g_table.f[3]=(PVOID)wrap_CreateEphemeralKey;
    g_table.f[4]=(PVOID)wrap_CreateHandshakeHash;
    g_table.f[7]=(PVOID)wrap_EnumCipherSuites;
    g_table.f[9]=(PVOID)wrap_FreeBuffer;
    g_table.f[11]=(PVOID)wrap_GenerateMasterKey;
    g_table.f[16]=(PVOID)wrap_ImportMasterKey;
    g_table.f[18]=(PVOID)wrap_LookupCipherSuiteInfo;
    g_table.f[20]=(PVOID)wrap_OpenProvider;
    g_table.f[23]=(PVOID)wrap_LookupCipherLengths;
    g_table.f[24]=(PVOID)wrap_CreateClientAuthHash;
    g_table.f[25]=(PVOID)wrap_GetPRF;
    /* slots 26 and 27 remain the real public ncrypt v3 callbacks. */
    g_ready=1;
    spin_unlock(&g_init_lock);
    return 1;
}

s32 STDCALL GetSChannelInterface(PVOID a1,SSL_TABLE_V3 **ppTable,PVOID a3){
    (void)a1;(void)a3;
    if(!ppTable) return NTE_INVALID_PARAMETER;
    *ppTable=(SSL_TABLE_V3*)0;
    if(!init_provider()) return NTE_NOT_SUPPORTED;
    *ppTable=&g_table;
    return 0;
}
