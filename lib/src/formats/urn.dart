// Copyright 2026 The Authors. See the AUTHORS file for details.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:collection/collection.dart';

/// A URN is a URI that uses the "urn:" scheme.
///
/// This format supports
/// [RFC 8141: Uniform Resource Names (URNs)](https://www.rfc-editor.org/info/rfc8141).
///
/// Unlike a URL, resolution of a URN generally requires another service.
class Urn {
  static const schemeName = 'urn';

  /// The namespace identifier.
  final String nid;

  /// The namespace specific string.
  final String nss;

  /// The fragment (f-component).
  final String fragment;

  /// Components to be used by resolution services.
  ///
  /// See: RFC 8141 2.3.1  r-component
  /// The rComponent isn't parsed further
  final String rComponent;

  /// Parameters to be used by the named resource.
  ///
  /// See: RFC 8141 2.3.2  q-component
  final Map<String, String> _qComponents;

  /// Constructor.
  ///
  /// As per RFC 8141 Section 3.1, the NSS and NID
  /// are converted to lower-case.
  Urn({
    required String nid,
    required String nss,
    this.fragment = '',
    this.rComponent = '',
    Map<String, String>? qComponents,
  }) : nid = nid.toLowerCase(),
       nss = nss.toLowerCase(),
       _qComponents = Map.from(qComponents ?? {});

  Map<String, String> get qComponentParameters =>
      UnmodifiableMapView(_qComponents);

  @override
  String toString() => [
    'urn:$nid:$nss',
    if (rComponent.isNotEmpty) '?+$rComponent',
    if (_qComponents.isNotEmpty)
      '?=${_qComponents.keys.map((k) => '$k=$_qComponents[k]').join("&")}',
    if (fragment.isNotEmpty) '#$fragment',
  ].join();

  Uri toUri() => Uri(
    scheme: schemeName,
    path: '$nid:$nss',
    query: [
      if (rComponent.isNotEmpty) '?+$rComponent',
      if (_qComponents.isNotEmpty)
        '?=${_qComponents.keys.map((k) => '$k=$_qComponents[k]').join("&")}',
    ].join(),
    fragment: fragment,
  );

  /// Equality is defined in RFC 8141 Section 3: URN equivalence.
  ///
  /// Note that:
  ///
  /// "If an r-component, q-component, or f-component (or any combination
  /// thereof) is included in a URN, it MUST be ignored for purposes of
  /// determining URN-equivalence."
  @override
  bool operator ==(Object other) =>
      other is Urn && other.nid == nid && other.nss == nss;

  @override
  int get hashCode => Object.hashAll([nid, nss]);

  static Urn? tryParseUri(Uri uri) {
    if (uri.scheme != schemeName) {
      throw ArgumentError.value(uri, 'uri', 'Not a URN');
    }

    var match = RegExp('^(?<nid>$_nid):(?<nss>$_nss)\$').firstMatch(uri.path);

    if (match == null) {
      return null;
    }

    var nid = match.namedGroup('nid');
    var nss = match.namedGroup('nss');

    if (nid == null || nss == null) {
      return null;
    }

    var query = '?${uri.query}';

    var rqComponentsMatch = RegExp(
      '(\\?\\+$_rComponent)?'
      '(\\?\\=$_qComponent)?',
    ).firstMatch(query);

    Map<String, String> qMap = {};
    String rcomponent = '';

    if (rqComponentsMatch != null) {
      rcomponent = rqComponentsMatch.namedGroup('rcomponent') ?? '';
      qMap = _parseQComponent(rqComponentsMatch.namedGroup('qcomponent') ?? '');
    }

    return Urn(
      nid: nid,
      nss: nss,
      qComponents: qMap,
      rComponent: rcomponent,
      fragment: uri.fragment,
    );
  }

  // unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
  static const _unreserved = r'[a-zA-Z0-9\-._~]';

  // HEXDIG    =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F" ; RFC 5234
  static const _hexDig = r'[0-9A-Fa-f]';

  // pct-encoded   = "%" HEXDIG HEXDIG
  static const _pctEncoded = '(%$_hexDig{2})';

  // sub-delims   = "!" / "$" / "&" / "'" / "(" / ")"
  //                 / "*" / "+" / "," / ";" / "="
  static const _subDelims = r"[!$&'()*+,;=]";

  // pchar    = unreserved / pct-encoded / sub-delims / ":" / "@"
  static const _pchar = '$_unreserved|$_pctEncoded|$_subDelims|[:@]';

  // NID = (alphanum) 0*30(ldh) (alphanum)
  // ldh = alphanum / "-"
  static const _nid = r'[a-zA-Z0-9][a-zA-Z0-9-]{0,30}[a-zA-Z0-9]';

  // NSS = pchar *(pchar / "/")
  static const _nss = '($_pchar)($_pchar|[/])*';

  // fragment      = *( pchar / "/" / "?" )
  static const _fragment = '(?<fragment>($_pchar|[/?])*)';

  // rq-components = [ "?+" r-component ]
  //                 [ "?=" q-component ]
  static const _rComponent = '(?<rcomponent>($_pchar)($_pchar|[/]|\\?(?!=))*)';
  static const _qComponent = '(?<qcomponent>($_pchar)($_pchar|[/?])*)';

  // assigned-name = "urn" ":" NID ":" NSS
  static const _assignedName = '(urn|URN):(?<nid>$_nid):(?<nss>$_nss)';

  static const _namestring =
      '$_assignedName'
      '(\\?\\+$_rComponent)?'
      '(\\?\\=$_qComponent)?'
      '(#$_fragment)?';

  static final _namestringRegEx = RegExp('^$_namestring\$');

  /// Parses the [input] URN and returns a [Urn] object.
  static Urn? tryParse(String input) {
    var match = _namestringRegEx.firstMatch(input);

    if (match == null) {
      return null;
    }

    var nid = match.namedGroup('nid');
    var nss = match.namedGroup('nss');

    var qMap = _parseQComponent(match.namedGroup('qcomponent') ?? '');

    if (nid == null || nss == null) {
      return null;
    }

    return Urn(
      nid: nid,
      nss: nss,
      rComponent: match.namedGroup('rcomponent') ?? '',
      qComponents: qMap,
      fragment: match.namedGroup('fragment') ?? '',
    );
  }

  static Map<String, String> _parseQComponent(String qcomponents) {
    var qMap = <String, String>{};
    if (qcomponents.isNotEmpty) {
      var qItems = qcomponents.split('&');

      for (var item in qItems) {
        var pair = item.split('=');
        qMap[pair[0]] = pair[1];
      }
    }
    return qMap;
  }
}
