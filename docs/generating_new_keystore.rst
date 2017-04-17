
================================
Generating new keystore fixtures
================================

Use this script to generate new keystore fixtures for running the test suite. This keystore includes a generated certificate set to expire 365 days after creation.


1. Enter the project's ``/script`` directory with ``cd script`` from the project root.

2. Execute the script to generate the keystore with ``./generate_keystore.sh``.

3. **When prompted to enter a keystore password, always use** ``importkey``.

4. **When prompted to overwrite existing keys and keystores, enter** ``y``.

5. When prompted to trust the certificate, enter ``yes``.

6. You will be prompted for the "export password" again, enter ``importkey``.

7. When prompted for the "source keystore password" again, enter ``importkey``.

8. When prompted to overwrite the existing test_keystore_vbms_server_key.p12, enter ``y``.

9. When prompted to overwrite the existing test_keystore.jks, enter ``y``.

10. Finally, the script will show the generated keystore and will prompt you for the password. Enter ``importkey``.


Valid Keystore Information
--------------------------

When the previous steps have been completed, the follow output will be generated based on the newly generated keystore. 

.. code-block:: bash
   
   + keytool -list -v -keystore /Users/amos/code/connect_vbms/script/../spec/fixtures/test_keystore.jks
   Enter keystore password:
   
   Keystore type: JKS
   Keystore provider: SUN
   
   Your keystore contains 3 entries
   
   Alias name: vbms_server_key
   Creation date: Oct 9, 2015
   Entry type: PrivateKeyEntry
   Certificate chain length: 1
   Certificate[1]:
   Owner: CN=test.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US
   Issuer: CN=test.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US
   Serial number: 80f883216d683966
   Valid from: Fri Oct 09 12:49:32 PDT 2015 until: Sat Oct 08 12:49:32 PDT 2016
   Certificate fingerprints:
      MD5:  67:11:3F:62:E1:15:93:78:09:62:1B:5A:C4:00:95:11
      SHA1: 8B:36:5D:4C:2D:6F:F6:79:8E:4C:EB:75:3E:61:A4:10:30:6A:10:9B
      Signature algorithm name: SHA256withRSA
      Version: 3
   
   Extensions:
   
   #1: ObjectId: 2.5.29.14 Criticality=false
   SubjectKeyIdentifier [
   KeyIdentifier [
   0000: F6 75 4E 51 D3 DF 75 69   68 60 1F 63 79 92 A0 AF  .uNQ..uih`.cy...
   0010: C9 03 8C 14                                        ....
   ]
   ]
   
   #2: ObjectId: 2.5.29.19 Criticality=false
   BasicConstraints:[
     CA:true
     PathLen:2147483647
   ]
   
   #3: ObjectId: 2.5.29.35 Criticality=false
   AuthorityKeyIdentifier [
   KeyIdentifier [
   0000: F6 75 4E 51 D3 DF 75 69   68 60 1F 63 79 92 A0 AF  .uNQ..uih`.cy...
   0010: C9 03 8C 14                                        ....
   ]
   
   [CN=test.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US]
   SerialNumber: [    80f88321 6d683966]
   ]
   
   
   
   *******************************************
   *******************************************
   
   
   Alias name: vbms_server_cert
   Creation date: Oct 9, 2015
   Entry type: trustedCertEntry
   
   Owner: CN=test.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US
   Issuer: CN=test.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US
   Serial number: 80f883216d683966
   Valid from: Fri Oct 09 12:49:32 PDT 2015 until: Sat Oct 08 12:49:32 PDT 2016
   Certificate fingerprints:
      MD5:  67:11:3F:62:E1:15:93:78:09:62:1B:5A:C4:00:95:11
      SHA1: 8B:36:5D:4C:2D:6F:F6:79:8E:4C:EB:75:3E:61:A4:10:30:6A:10:9B
      Signature algorithm name: SHA256withRSA
      Version: 3
   
   Extensions:
   
   #1: ObjectId: 2.5.29.14 Criticality=false
   SubjectKeyIdentifier [
   KeyIdentifier [
   0000: F6 75 4E 51 D3 DF 75 69   68 60 1F 63 79 92 A0 AF  .uNQ..uih`.cy...
   0010: C9 03 8C 14                                        ....
   ]
   ]
   
   #2: ObjectId: 2.5.29.19 Criticality=false
   BasicConstraints:[
     CA:true
     PathLen:2147483647
   ]
   
   #3: ObjectId: 2.5.29.35 Criticality=false
   AuthorityKeyIdentifier [
   KeyIdentifier [
   0000: F6 75 4E 51 D3 DF 75 69   68 60 1F 63 79 92 A0 AF  .uNQ..uih`.cy...
   0010: C9 03 8C 14                                        ....
   ]
   
   [CN=test.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US]
   SerialNumber: [    80f88321 6d683966]
   ]
   
   
   
   *******************************************
   *******************************************
   
   
   Alias name: importkey
   Creation date: Oct 9, 2015
   Entry type: PrivateKeyEntry
   Certificate chain length: 1
   Certificate[1]:
   Owner: CN=client.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US
   Issuer: CN=client.vbms.va.gov, O=USDS, L=DC, ST=Washington, C=US
   Serial number: 9f8bfd380977012a
   Valid from: Fri Oct 09 12:49:32 PDT 2015 until: Sat Oct 08 12:49:32 PDT 2016
   Certificate fingerprints:
      MD5:  DD:75:28:6B:13:C9:AA:8F:BB:A3:AE:B4:B4:9D:7B:08
      SHA1: 22:23:C4:6A:E8:77:0B:22:11:FC:5D:D3:0B:D6:7F:2F:4D:DF:C3:A5
      Signature algorithm name: SHA256withRSA
      Version: 1
   
   
   *******************************************
   *******************************************
   
