import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class DeviceInfoWindows {
  bool _isInitialized = false;
  bool _isConnected = false;

  late IWbemServices _pSvc;
  late IWbemLocator _pLoc;

  /// Initializes the class.
  void _initialize() {
    // Initialize COM
    var hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(hr)) {
      throw COMException(hr);
    }

    // Initialize security model
    hr = CoInitializeSecurity(
        nullptr,
        -1, // COM negotiates service
        nullptr, // Authentication services
        nullptr, // Reserved
        RPC_C_AUTHN_LEVEL_DEFAULT, // authentication
        RPC_C_IMP_LEVEL_IMPERSONATE, // Impersonation
        nullptr, // Authentication info
        EOLE_AUTHENTICATION_CAPABILITIES.EOAC_NONE, // Additional capabilities
        nullptr // Reserved
        );

    if (FAILED(hr)) {
      // If RPC_E_TOO_LATE, we don't have to bail; CoInititializeSecurity() can
      // only be called once per process.
      if (hr != RPC_E_TOO_LATE) {
        final exception = COMException(hr);
        print(exception.toString());

        close();
        throw exception;
      }
    }

    _isInitialized = true;
  }

  void _connect() {
    if (!_isInitialized) {
      _initialize();
    }

    // Obtain the initial locator to Windows Management
    // on a particular host computer.
    _pLoc = WbemLocator.createInstance();

    final proxy = calloc<IntPtr>();

    // Connect to the root\cimv2 namespace with the
    // current user and obtain pointer pSvc
    // to make IWbemServices calls.

    var hr = _pLoc.ConnectServer(
        TEXT('ROOT\\CIMV2'), // WMI namespace
        nullptr, // User name
        nullptr, // User password
        nullptr, // Locale
        NULL, // Security flags
        nullptr, // Authority
        nullptr, // Context object
        proxy.cast() // IWbemServices proxy
        );

    if (FAILED(hr)) {
      final exception = COMException(hr);
      print(exception.toString());

      _disconnect();
      close();
      throw exception;
    }

    print('Connected to ROOT\\CIMV2 WMI namespace');

    _pSvc = IWbemServices(proxy.cast());

    // Set the IWbemServices proxy so that impersonation
    // of the user (client) occurs.
    hr = CoSetProxyBlanket(
        Pointer.fromAddress(proxy.value), // the proxy to set
        RPC_C_AUTHN_WINNT, // authentication service
        RPC_C_AUTHZ_NONE, // authorization service
        nullptr, // Server principal name
        RPC_C_AUTHN_LEVEL_CALL, // authentication level
        RPC_C_IMP_LEVEL_IMPERSONATE, // impersonation level
        nullptr, // client identity
        EOLE_AUTHENTICATION_CAPABILITIES.EOAC_NONE // proxy capabilities
        );

    if (FAILED(hr)) {
      final exception = COMException(hr);
      print(exception.toString());

      _pSvc.Release();
      _disconnect();
      close();
      throw exception;
    }

    _isConnected = true;
  }

  /// Returns a list of running processes on the current system.
  List<String> listRunningProcesses() {
    final processes = <String>[];

    if (!_isConnected) {
      _connect();
    }

    // Use the IWbemServices pointer to make requests of WMI.

    final pEnumerator = calloc<Pointer<COMObject>>();
    IEnumWbemClassObject enumerator;

    // For example, query for all the running processes
    var hr = _pSvc.ExecQuery(
        TEXT('WQL'),
        TEXT('SELECT * FROM Win32_Process'),
        WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_FORWARD_ONLY |
            WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr,
        pEnumerator);

    if (FAILED(hr)) {
      final exception = COMException(hr);
      print(exception.toString());

      _pSvc.Release();
      _disconnect();
      close();

      throw exception;
    } else {
      enumerator = IEnumWbemClassObject(pEnumerator.cast());

      final uReturn = calloc<Uint32>();

      var idx = 0;
      while (enumerator.ptr.address > 0) {
        final pClsObj = calloc<Pointer<COMObject>>();

        hr = enumerator.Next(
            WBEM_TIMEOUT_TYPE.WBEM_INFINITE, 1, pClsObj, uReturn);

        // Break out of the while loop if we've run out of processes to inspect
        if (uReturn.value == 0) break;

        idx++;

        final clsObj = IWbemClassObject(pClsObj.cast());

        final processName = _getProperty(clsObj, 'Name');
        if (processName.isNotEmpty) {
          processes.add(processName);
        }

        clsObj.Release();
      }
      print('$idx processes found.');
    }

    _pSvc.Release();
    _disconnect();
    enumerator.Release();

    return processes;
  }

  String _getProperty(IWbemClassObject clsObj, String key) {
    final vtProp = calloc<VARIANT>();
    final keyPtr = key.toNativeUtf16();

    try {
      final hr = clsObj.Get(keyPtr, 0, vtProp, nullptr, nullptr);

      if (SUCCEEDED(hr)) {
        return vtProp.ref.bstrVal.toDartString();
      } else {
        return '';
      }
    } finally {
      VariantClear(vtProp);
      free(keyPtr);
    }
  }

  void _disconnect() {
    _pLoc.Release();

    _isConnected = false;
  }

  /// Closes the connection to WMI.
  ///
  /// You should call this method before disposing of this class to uninitialize
  /// the underlying COM library.
  void close() {
    CoUninitialize();

    _isInitialized = false;
  }
}
