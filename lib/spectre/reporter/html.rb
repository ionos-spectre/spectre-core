require 'cgi'
require 'base64'

module Spectre::Reporter
  class HTML
    def initialize config
      @config = config
      @date_format = '%FT%T.%L'
    end

    def get_error_info error
      non_spectre_files = error.backtrace.select { |x| !x.include? 'lib/spectre' }

      if non_spectre_files.count > 0
        causing_file = non_spectre_files.first
      else
        causing_file = error.backtrace[0]
      end

      matches = causing_file.match(/(.*\.rb):(\d+)/)

      return [nil, nil] unless matches

      file, line = matches.captures
      file.slice!(Dir.pwd + '/')

      return [file, line]
    end

    def read_resource filename
      file_path = File.join(__dir__, '../../../resources/', filename)

      File.open(file_path, 'rb') do |file|
        return file.read
      end
    end

    def report run_infos
      now = Time.now

      failures = run_infos.select { |x| x.failure != nil }
      errors = run_infos.select { |x| x.error != nil }
      skipped = run_infos.select { |x| x.skipped? }
      succeeded_count = run_infos.count - failures.count - errors.count - skipped.count

      if failures.count > 0
        overall_status = 'failed'
      elsif errors.count > 0
        overall_status = 'error'
      elsif skipped.count > 0
        overall_status = 'skipped'
      else
        overall_status = 'success'
      end

      json_report = {
        command: $COMMAND,
        project: @config['project'],
        date: now.strftime(@date_format),
        environment: @config['environment'],
        hostname: Socket.gethostname,
        duration: run_infos.sum { |x| x.duration },
        failures: failures.count,
        errors: errors.count,
        skipped: skipped.count,
        succeeded: succeeded_count,
        total: run_infos.count,
        overall_status: overall_status,
        tags: run_infos
          .map { |x| x.spec.tags }
          .flatten
          .uniq
          .sort,
        run_infos: run_infos.map do |run_info|
          failure = nil
          error = nil

          if run_info.failed? and not run_info.failure.cause
            failure_message = "Expected #{run_info.failure.expectation}"
            failure_message += " with #{run_info.data}" if run_info.data
            failure_message += " but it failed"
            failure_message += " with message: #{run_info.failure.message}" if run_info.failure.message

            failure = {
              message: failure_message,
              expected: run_info.failure.expected,
              actual: run_info.failure.actual,
            }
          end

          if run_info.error or (run_info.failed? and run_info.failure.cause)
            error = run_info.error || run_info.failure.cause

            file, line = get_error_info(error)

            error = {
              type: error.class.name,
              message: error.message,
              file: file,
              line: line,
              stack_trace: error.backtrace,
            }
          end

          {
            status: run_info.status,
            subject: run_info.spec.subject.desc,
            context: run_info.spec.context.__desc,
            tags: run_info.spec.tags,
            name: run_info.spec.name,
            desc: run_info.spec.desc,
            file: run_info.spec.file,
            started: run_info.started.strftime(@date_format),
            finished: run_info.finished.strftime(@date_format),
            duration: run_info.duration,
            properties: run_info.properties,
            data: run_info.data,
            failure: failure,
            error: error,
            # the <script> element has to be escaped in any string, as it causes the inline JavaScript to break
            log: run_info.log.map { |x| [x[0], x[1].to_s.gsub(/\<(\/*script)/, '<`\1'), x[2], x[3]] },
          }
        end,
        config: @config.obfuscate!,
      }

      vuejs_content = read_resource('vue.global.prod.js')
      open_sans_font = Base64.strict_encode64 read_resource('OpenSans-Regular.ttf')
      fa_solid = Base64.strict_encode64 read_resource('fa-solid-900.ttf')
      fa_regular = Base64.strict_encode64 read_resource('fa-regular-400.ttf')
      icon = read_resource('spectre_icon.svg')

      html_str = <<~HTML
        <html>
          <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            <title>Spectre Report</title>

            <!-- https://unpkg.com/vue@3.2.29/dist/vue.global.prod.js -->
            <script>#{vuejs_content}</script>

            <style>
              @font-face{
                font-family: 'Open Sans Regular';
                src: url(data:font/ttf;base64,#{open_sans_font}) format('truetype');
              }

              @font-face{
                font-family: 'Font Awesome';
                font-weight: 900;
                src: url(data:font/ttf;base64,#{fa_solid}) format('truetype');
              }

              @font-face{
                font-family: 'Font Awesome';
                font-weight: 400;
                src: url(data:font/ttf;base64,#{fa_regular}) format('truetype');
              }

              * {
                box-sizing: border-box;
                font-weight: inherit;
                line-height: 1.5em;
                font-size: inherit;
                margin: 0rem;
                padding: 0rem;
              }

              html, body {
                padding: 0rem;
                margin: 0rem;
              }

              body {
                font-family: 'Open Sans Regular', Arial, sans-serif;
                color: #223857;
                font-size: 16px;
                background-color: #f6f7f8;
              }

              section {
                margin-bottom: 2rem;
              }

              #spectre-banner {
                padding: 1rem;
                font-weight: bold;
                text-align: center;
                text-transform: uppercase;
              }

              #spectre-report {
                padding: 2rem;
                width: 90%;
                margin: auto;
              }

              #spectre-tags {
                text-align: center;
              }

              #spectre-logo {
                display: block;
                margin: 1.5rem auto;
              }

              fieldset {
                border: 1px solid #dfe2e7;
                border-radius: 3px;
                margin-bottom: 0.3rem;
                width: 100%;
                padding: 0rem 1rem 1rem 1rem;
              }

              legend {
                color: #bcc5d1;
                font-size: 0.9rem;
                padding: 0.3em;
              }

              th {
                font-weight: bold;
                text-align: right;
              }

              td {
                padding: 0.2em;
              }

              ul {
                padding: 0rem 0rem 0rem 1rem;
              }

              /* spectre-logo */

              .spectre-status-success .spectre-logo-eye {
                fill: #9ddf1c !important;
              }

              .spectre-status-failed .spectre-logo-eye {
                fill: #e61160 !important;
              }

              .spectre-status-error .spectre-logo-eye {
                fill: #f5d915 !important;
              }

              .spectre-status-skipped .spectre-logo-eye {
                fill: #c1d5d9 !important;
              }

              /* spectre-controls */

              ul.spectre-controls {
                list-style: none;
                margin: 0rem;
                padding: 0rem;
                text-align: center;
              }

              ul.spectre-controls > li {
                display: inline;
                margin-right: 1rem;
              }

              .spectre-controls-clear {
                position: relative;
              }

              .spectre-controls-clear:before {
                font-family: 'Font Awesome';
                font-weight: 900;
                content: '\\f0b0';
              }

              .spectre-controls-clear.active:before {
                font-family: 'Font Awesome';
                font-weight: 900;
                content: '\\e17b';
              }

              .spectre-filter-count {
                font-size: 0.7em;
                background-color: #223857;
                color: #fff;
                border-radius: 999px;
                padding: 0em 0.5em;
                position: absolute;
                top: -1em;
              }

              .spectre-link {
                display: inline;
                border-bottom: 2px solid #3196d6;
                text-decoration: none;
                cursor: pointer;
              }

              .spectre-link:hover {
                background-color: #dbedf8;
              }

              legend.spectre-toggle {
                cursor: pointer;
                user-select: none;
              }

              legend.spectre-toggle:before {
                content: '+';
                margin-right: 0.2em;
              }

              .spectre-expander:before {
                font-family: 'Font Awesome';
                font-weight: 400;
                display: inline-block;
                cursor: pointer;
                content: '\\f0fe';
                margin-right: 0.5rem;
              }

              .active > .spectre-expander:before {
                content: '\\f146';
              }

              #spectre-environment,
              .spectre-command {
                display: block;
                font-family: monospace;
                background-color: #223857;
                color: #fff;
                border-radius: 3px;
                padding: 0.5rem;
              }

              .spectre-command:before {
                content: '$';
                margin-right: 0.5rem;
              }

              /* spectre-summary */

              .spectre-summary {
                text-align: center;
              }

              .spectre-summary span {
                font-size: 1.5rem;
              }

              .spectre-summary span:not(:last-child) {
                margin-right: 2em;
              }

              span.spectre-summary-project {
                display: block;
                font-size: 2.5em;
                text-transform: uppercase;
                margin: 1rem 0rem !important;
              }

              .spectre-summary-environment {
                font-family: monospace;
              }

              .spectre-summary-environment:before,
              .spectre-summary-date:before,
              .spectre-summary-duration:before,
              .spectre-summary-host:before {
                font-family: 'Font Awesome';
                margin-right: 0.5em;
              }

              .spectre-summary-environment:before {
                font-weight: 900;
                content: '\\e587';
              }

              .spectre-summary-date:before {
                content: '\\f133';
              }

              .spectre-summary-duration:before {
                font-weight: 900;
                content: '\\f2f2';
              }

              .spectre-summary-host:before {
                font-weight: 900;
                content: '\\e4e5';
              }

              ul.spectre-summary-result {
                list-style: none;
                padding: 0rem;
                margin: 0rem;
                text-align: center;
              }

              ul.spectre-summary-result > li {
                display: inline;
                margin-right: 1rem;
              }

              ul.spectre-tags {
                list-style: none;
                padding: 0rem;
                margin: 0rem;
                user-select: none;
              }

              ul.spectre-tags > li {
                display: inline-block;
                line-height: 1.5rem;
                cursor: pointer;
              }

              .spectre-tag {
                color: #11c7e6;
                padding: 0rem 0.5rem;
              }

              .spectre-tag:before {
                content: '#';
              }

              .spectre-tag.active {
                background-color: #11c7e6;
                color: #223857;
                border-radius: 999px;
              }

              /* spectre-button */

              .spectre-button {
                background-color: #11c7e6;
                border: 3px solid #11c7e6;
                color: #0b2a63;
                cursor: pointer;
                border-radius: 999px;
                padding: 0.5rem 1rem;
                font-weight: bold;
                user-select: none;
              }

              .spectre-button:hover {
                background-color: #7fe4f6;
                border-color: #7fe4f6;
              }

              .spectre-button:active {
                background-color: #d2f6fc;
                border-color: #d2f6fc;
              }

              .spectre-button.disabled {
                background: none !important;
                border-color: rgba(0, 0, 0, 0.1) !important;
                color: rgba(0, 0, 0, 0.175) !important;
                cursor: default !important;
              }

              .spectre-button.inactive {
                background: none;
                border-color: #0b2a63;
              }

              .spectre-button.inactive:hover {
                background-color: #0b2a63;
                border-color: #0b2a63;
                color: #fff;
              }

              .spectre-button.inactive:active {
                background-color: #0b3476;
                border-color: #0b3476;
                color: #fff;
              }

              /* spectre-badge */

              .spectre-badge {
                font-size: 0.8em;
                font-weight: bold;
                background-color: #11c7e6;
                color: #0b2a63;
                border-radius: 999rem;
                padding: 0.2rem 0.8rem;
              }

              /* spectre-result */

              .spectre-result-subjects {
                list-style: none;
                padding: 3rem;
                margin: 0rem;
                background-color: #fff;
                border-radius: 3px;
                box-shadow: 0 2px 5px 0 rgb(0 0 0 / 20%);
              }

              .spectre-result-runinfos {
                display: none;
              }

              .active > .spectre-result-runinfos {
                display: block;
              }

              ul.spectre-result-contexts, ul.spectre-result-runinfos {
                list-style: none;
                margin: 0rem;
              }

              .spectre-result-subjects > li {
                margin-bottom: 1rem;
              }

              /* spectre-subject */

              .spectre-subject-desc {
                font-weight: bold;
                font-size: 1.3rem;
              }

              /* spectre-context */

              .spectre-context-desc {
                font-style: italic;
                color: #11c7e6;
              }

              .spectre-context {
                line-height: 1.5em;
              }

              /* spectre-runinfo */

              .spectre-runinfo {
                padding: 0.8rem 1rem;
              }

              .spectre-runinfo:not(:last-child) {
                border-bottom: 1px solid rgb(0, 0, 0, 0.1);
              }

              .spectre-runinfo-description > span {
                margin: 0em 0.2em;
              }

              .spectre-runinfo-details {
                margin: 1rem 0rem;
                padding-left: 1rem;
                display: none;
              }

              .spectre-runinfo.active .spectre-runinfo-details {
                display: block;
              }

              .spectre-description-data {
                color: #11c7e6;
              }

              .spectre-description-name {
                color: #9aa7b9;
              }

              .spectre-description-data:before,
              .spectre-description-name:before {
                content: '[';
              }

              .spectre-description-data:after,
              .spectre-description-name:after {
                content: ']';
              }

              .spectre-file {
                font-family: monospace;
              }

              .spectre-code {
                font-family: monospace;
              }

              .spectre-date {
                font-style: italic;
              }

              /* spectre-details */

              .spectre-details-status {
                text-transform: uppercase;
              }

              /* spectre icons */

              .spectre-description-status:before {
                font-family: 'Font Awesome';
                font-weight: 900;
                margin: 0em 0.3em;
              }

              .spectre-runinfo.spectre-status-success .spectre-description-status:before {
                content: '\\f00c';
                color: #9ddf1c;
              }

              .spectre-runinfo.spectre-status-failed .spectre-description-status:before {
                content: '\\f7a9';
                color: #e61160;
              }

              .spectre-runinfo.spectre-status-error .spectre-description-status:before {
                content: '\\f057';
                font-weight: 400;
                color: #f5d915;
              }

              .spectre-runinfo.spectre-status-skipped .spectre-description-status:before {
                content: '\\f04e';
                color: #c1d5d9;
              }

              /* spectre-status colors */

              /* spectre-status colors SUCCESS */

              .spectre-runinfo.spectre-status-success .spectre-details-status,
              .spectre-button.spectre-summary-succeeded,
              .spectre-status-success #spectre-banner {
                background-color: #9ddf1c;
                border-color:  #9ddf1c;
              }

              .spectre-button.spectre-summary-succeeded:hover {
                background-color: #c1f55b;
                border-color:  #c1f55b;
                color: #0b2a63;
              }

              .spectre-button.spectre-summary-succeeded:active {
                background-color: #d3ff7c;
                border-color:  #d3ff7c;
                color: #0b2a63;
              }

              .spectre-button.inactive.spectre-summary-succeeded {
                background: none;
                border-color: #9ddf1c;
                color: #0b2a63;
              }

              .spectre-button.inactive.spectre-summary-succeeded:hover {
                background-color: #9ddf1c;
                border-color: #9ddf1c;
              }

              .spectre-button.inactive.spectre-summary-succeeded:active {
                background-color: #83bd11;
                border-color: #83bd11;
              }

              .spectre-log-level-info {
                color: #9ddf1c;
              }

              /* spectre-status colors FAILED */

              .spectre-runinfo.spectre-status-failed .spectre-details-status,
              .spectre-button.spectre-summary-failures,
              .spectre-status-failed #spectre-banner {
                background-color: #e61160;
                border-color:  #e61160;
              }

              .spectre-button.spectre-summary-failures:hover {
                background-color: #f56198;
                border-color:  #f56198;
                color: #0b2a63;
              }

              .spectre-button.spectre-summary-failures:active {
                background-color: #ffadcb;
                border-color:  #ffadcb;
                color: #0b2a63;
              }

              .spectre-button.inactive.spectre-summary-failures {
                background: none;
                border-color:  #e61160;
                color: #0b2a63;
              }

              .spectre-button.inactive.spectre-summary-failures:hover {
                background-color: #e61160;
                border-color: #e61160;
              }

              .spectre-button.inactive.spectre-summary-failures:active {
                background-color: #bb084a;
                border-color: #bb084a;
              }

              .spectre-log-level-error {
                color: #e61160;
              }

              /* spectre-status colors ERROR */

              .spectre-runinfo.spectre-status-error .spectre-details-status,
              .spectre-button.spectre-summary-errors,
              .spectre-status-error #spectre-banner {
                background-color: #f5d915;
                border-color:  #f5d915;
              }

              .spectre-button.spectre-summary-errors:hover {
                background-color: #fde95e;
                border-color:  #fde95e;
                color: #0b2a63;
              }

              .spectre-button.spectre-summary-errors:active {
                background-color: #fff29b;
                border-color:  #fff29b;
                color: #0b2a63;
              }

              .spectre-button.inactive.spectre-summary-errors {
                background: none;
                border-color: #f5d915;
                color: #0b2a63;
              }

              .spectre-button.inactive.spectre-summary-errors:hover {
                background-color: #f5d915;
                border-color: #f5d915;
              }

              .spectre-button.inactive.spectre-summary-errors:active {
                background-color: #e7ca00;
                border-color: #e7ca00;
              }

              .spectre-log-level-warn {
                color: #f5d915;
              }

              /* spectre-status colors SKIPPED */

              .spectre-runinfo.spectre-status-skipped .spectre-details-status,
              .spectre-button.spectre-summary-skipped,
              .spectre-status-skipped #spectre-banner {
                background-color: #c1d5d9;
                border-color:  #c1d5d9;
              }

              .spectre-log-level-debug {
                color: #c1d5d9;
              }

              /* spectre-log */

              .spectre-log {
                font-family: monospace;
                font-size: 0.8rem;
                list-style: none;
                padding: 0rem;
                margin: 0rem;
              }

              .spectre-log-entry {
                display: block;
                font-family: monospace;
                white-space: pre;
              }

              .spectre-log-timestamp {
                font-style: italic;
                color: rgba(0, 0, 0, 0.5);
              }

              .spectre-log-timestamp:before {
                content: '[';
                color: #000;
              }

              .spectre-log-timestamp:after {
                content: ']';
                color: #000;
              }

              .spectre-log-level {
                text-transform: uppercase;
              }
            </style>
          </head>
          <body>
            <div id="app">
              <div :class="'spectre-status-' + spectreReport.overall_status">
                <div id="spectre-banner">{{ spectreReport.overall_status }}</div>

                <div class="spectre-summary">
                  #{icon}

                  <span class="spectre-summary-project">{{ spectreReport.project }}</span>

                  <span class="spectre-summary-environment">{{ spectreReport.environment }}</span>
                  <span class="spectre-summary-date">{{ new Date(spectreReport.date).toLocaleString() }}</span>
                  <span class="spectre-summary-duration">{{ spectreReport.duration.toDurationString() }}</span>
                  <span class="spectre-summary-host">{{ spectreReport.hostname }}</span>
                </div>

                <div id="spectre-report">
                  <section>
                    <div class="spectre-command">{{ spectreCommand }}</div>
                  </section>

                  <section id="spectre-tags">
                    <ul class="spectre-tags">
                      <li class="spectre-tag" v-for="tag in spectreReport.tags" @click="toggleTagFilter(tag)" :class="{ active: tagFilter.includes(tag)}">{{ tag }}</li>
                    </ul>
                  </section>

                  <section>
                    <ul class="spectre-summary-result">
                      <li
                        class="spectre-button spectre-summary-succeeded"
                        :class="{ disabled: spectreReport.succeeded == 0, inactive: statusFilter != null && statusFilter != 'success' }"
                        @click="filter('success')">{{ spectreReport.succeeded }} succeeded</li>

                      <li
                        class="spectre-button spectre-summary-skipped"
                        :class="{ disabled: spectreReport.skipped == 0, inactive: statusFilter != null && statusFilter != 'skipped' }"
                        @click="filter('skipped')">{{ spectreReport.skipped }} skipped</li>

                      <li
                        class="spectre-button spectre-summary-failures"
                        :class="{ disabled: spectreReport.failures == 0, inactive: statusFilter != null && statusFilter != 'failed' }"
                        @click="filter('failed')">{{ spectreReport.failures }} failures</li>

                      <li
                        class="spectre-button spectre-summary-errors"
                        :class="{ disabled: spectreReport.errors == 0, inactive: statusFilter != null && statusFilter != 'error' }"
                        @click="filter('error')">{{ spectreReport.errors }} errors</li>

                      <li
                        class="spectre-button spectre-summary-total"
                        :class="{ disabled: spectreReport.total == 0, inactive: statusFilter != null }"
                        @click="showAll()">{{ spectreReport.total }} total</li>
                    </ul>
                  </section>

                  <section>
                    <ul class="spectre-section spectre-controls">
                      <li class="spectre-link" @click="collapseAll()">collapse all</li>
                      <li class="spectre-link" @click="expandAll()">expand all</li>
                      <li class="spectre-link spectre-controls-clear" :class="{ active: tagFilter.length > 0 || statusFilter != null }" @click="clearFilter()">
                        <span class="spectre-filter-count">{{ filteredResults.length }}/{{ spectreReport.run_infos.length }}<span>
                      </li>
                    </ul>
                  </section>

                  <section>
                    <ul class="spectre-result-subjects">
                      <li class="spectre-subject" v-for="(contexts, subject) in mappedResults">
                        <span class="spectre-subject-desc">{{ subject }}</span>

                        <ul class="spectre-result-contexts">
                          <li class="spectre-context" v-for="(runInfos, context) in contexts" :class="{ active: expandedContexts.includes(subject + '_' + context) }">
                            <span class="spectre-expander" @click="toggleContext(subject, context)"></span>
                            <span class="spectre-context-desc">{{ context }}</span>

                            <ul class="spectre-result-runinfos">
                              <li class="spectre-runinfo" v-for="runInfo in runInfos" :class="['spectre-status-' + runInfo.status, { active: shownDetails.includes(runInfo) }]">
                                <span class="spectre-expander" @click="showDetails(runInfo)"></span>
                                <span class="spectre-runinfo-description">
                                  <span class="spectre-description-status"></span>
                                  <span class="spectre-description-name">{{ runInfo.name }}</span>
                                  <span class="spectre-description-data" v-if="runInfo.data">{{ runInfo.data }}</span>
                                  <span class="spectre-description-subject">{{ subject }}</span>
                                  <span class="spectre-description-spec">{{ runInfo.desc }}</span>
                                </span>

                                <div class="spectre-runinfo-details">
                                  <fieldset>
                                    <legend>Run Info</legend>

                                    <table>
                                      <tr><th>Status</th><td><span class="spectre-badge spectre-details-status">{{ runInfo.status }}</span></td></tr>
                                      <tr><th>Name</th><td>{{ runInfo.name }}</td></tr>
                                      <tr><th>Description</th><td>{{ runInfo.desc }}</td></tr>
                                      <tr><th>Tags</th><td>
                                        <ul class="spectre-tags">
                                          <li class="spectre-tag" v-for="tag in runInfo.tags" @click="toggleTagFilter(tag)" :class="{ active: tagFilter.includes(tag)}">{{ tag }}</li>
                                        </ul>
                                      </td></tr>
                                      <tr><th>File</th><td><span class="spectre-file">{{ runInfo.file }}<span></td></tr>
                                      <tr><th>Started</th><td><span class="spectre-date">{{ runInfo.started }}<span></td></tr>
                                      <tr><th>Finished</th><td><span class="spectre-date">{{ runInfo.finished }}<span></td></tr>
                                      <tr><th>Duration</th><td>{{ runInfo.duration.toDurationString() }}</td></tr>
                                    </table>
                                  </fieldset>

                                  <fieldset class="spectre-runinfo-data" v-if="runInfo.data">
                                    <legend>Data</legend>
                                    <pre>{{ runInfo.data }}</pre>
                                  </fieldset>

                                  <fieldset class="spectre-runinfo-properties" v-if="Object.keys(runInfo.properties).length > 0">
                                    <legend>Properties</legend>

                                    <table>
                                      <tr v-for="(item, key) in runInfo.properties" :key="key"><th>{{ key }}</th><td>{{ item }}</td></tr>
                                    </table>
                                  </fieldset>

                                  <fieldset class="spectre-runinfo-failure" v-if="runInfo.failure">
                                    <legend>Failure</legend>

                                    <table>
                                      <tr><th>Message</th><td>{{ runInfo.failure.message }}</td></tr>
                                      <tr><th>Expected</th><td>{{ runInfo.failure.expected }}</td></tr>
                                      <tr><th>Actual</th><td>{{ runInfo.failure.actual }}</td></tr>
                                    </table>
                                  </fieldset>

                                  <fieldset class="spectre-runinfo-error" v-if="runInfo.error">
                                    <legend>Error</legend>

                                    <table>
                                      <tr><th>File</th><td><span class="spectre-file">{{ runInfo.error.file }}</span></td></tr>
                                      <tr><th>Line</th><td>{{ runInfo.error.line }}</td></tr>
                                      <tr><th>Type</th><td><span class="spectre-code">{{ runInfo.error.type }}</span></td></tr>
                                      <tr><th>Message</th><td>{{ runInfo.error.message }}</td></tr>
                                    </table>
                                  </fieldset>

                                  <fieldset class="spectre-runinfo-stacktrace" v-if="runInfo.error && runInfo.error.stack_strace">
                                    <ul>
                                      <li v-for="stackTraceEntry in runInfo.error.stack_strace">{{ stackTraceEntry }}</li>
                                    </ul>
                                  </fieldset>

                                  <fieldset class="spectre-runinfo-log" v-if="runInfo.log && runInfo.log.length > 0">
                                    <legend class="spectre-toggle" @click="toggleLog(runInfo)">Log</legend>

                                    <ul class="spectre-log" v-if="shownLogs.includes(runInfo)">
                                      <li v-for="logEntry in runInfo.log" class="spectre-log-entry">
                                        <span class="spectre-log-timestamp">{{ logEntry[0] }}</span> <span class="spectre-log-level" :class="'spectre-log-level-' + logEntry[2]">{{ logEntry[2] }}</span> -- <span class="spectre-log-name">{{ logEntry[3] }}</span>: <span class="spectre-log-message">{{ logEntry[1] }}</span>
                                      </li>
                                    </ul>
                                  </fieldset>
                                <div>
                              </li>
                            </ul>
                          </li>
                        </ul>
                      </li>
                    </ul>
                  </section>

                  <section id="spectre-environment">
                    <pre>#{ CGI::escapeHTML(YAML.dump json_report[:config]) }</pre>
                  </section>
                </div>
              </div>
            </div>

            <script>
              Array.prototype.groupBy = function(callbackFn) {
                const map = new Object();
                this.forEach((item) => {
                    const key = callbackFn(item);
                    const collection = map[key];
                    if (!collection) {
                        map[key] = [item];
                    } else {
                        collection.push(item);
                    }
                });
                return map;
              }

              Object.prototype.map = function(callbackFn) {
                return Object
                  .entries(this)
                  .map(callbackFn);
              };

              Array.prototype.toDict = function() {
                return Object.assign({}, ...this.map((x) => ({[x[0]]: x[1]})));
              };

              Array.prototype.distinct = function() {
                return this.filter((value, index, self) => self.indexOf(value) === index);
              };

              Number.prototype.toDurationString = function() {
                let date = new Date(this * 1000);
                let hours = date.getUTCHours();
                let minutes = date.getUTCMinutes();
                let seconds = date.getUTCSeconds();
                let milliseconds = date.getUTCMilliseconds();

                let durationString = '';

                if (hours > 0) {
                  durationString += `${hours}h`
                }

                if (minutes > 0 || hours > 0) {
                  if (durationString.length > 0) {
                    durationString += ' ';
                  }

                  durationString += `${minutes}m`
                }

                if (seconds > 0 || minutes > 0) {
                  if (durationString.length > 0) {
                    durationString += ' ';
                  }

                  durationString += `${seconds}s`
                }

                if (milliseconds > 0) {
                  if (durationString.length > 0) {
                    durationString += ' ';
                  }

                  durationString += `${milliseconds}ms`
                }

                if (durationString.length == 0) {
                  return `${this}s`
                }

                return durationString;
              }

              const { createApp } = Vue;

              window.App = createApp({
                data() {
                  return {
                    spectreReport: #{json_report.to_json},
                    statusFilter: null,
                    tagFilter: [],
                    shownDetails: [],
                    shownLogs: [],
                    expandedContexts: [],
                  }
                },
                mounted() {
                  this.expandAll();
                },
                computed: {
                  filteredResults() {
                    return this.spectreReport.run_infos
                      .filter(x => this.statusFilter == null || x.status == this.statusFilter)
                      .filter(x => this.tagFilter.length == 0 || x.tags.filter(x => this.tagFilter.includes(x)).length > 0);
                  },
                  mappedResults() {
                    return this.filteredResults
                      .groupBy(x => x.subject)
                      .map(([key, val]) => [key, val.groupBy(x => x.context || '[main]')])
                      .toDict();
                  },
                  spectreCommand() {
                    let cmd = this.spectreReport.command;
                    let filteredSpecs = this.filteredResults;

                    if (this.statusFilter == null && this.tagFilter.length > 0) {
                      cmd += ` -t ${this.tagFilter.join(',')}`

                    } else if (this.statusFilter != null && filteredSpecs.length > 0) {
                      cmd += ` -s ${this.filteredResults.map(x => x.name).join(',')}`
                    }

                    return cmd;
                  },
                },
                methods: {
                  filter(status) {
                    if (this.statusFilter == status) {
                      this.statusFilter = null;
                      return;
                    }

                    if (this.spectreReport.run_infos.filter(x => x.status == status).length == 0) {
                      return;
                    }

                    this.statusFilter = status;
                  },
                  showAll() {
                    this.statusFilter = null;
                  },
                  toggleTagFilter(tag) {
                    let index = this.tagFilter.indexOf(tag);

                    if (index > -1) {
                      this.tagFilter.splice(index, 1);
                    } else {
                      this.tagFilter.push(tag)
                    }
                  },
                  clearFilter() {
                    this.statusFilter = null;
                    this.tagFilter = [];
                  },
                  showDetails(runInfo) {
                    let index = this.shownDetails.indexOf(runInfo);

                    if (index > -1) {
                      this.shownDetails.splice(index, 1);
                    } else {
                      this.shownDetails.push(runInfo)
                    }
                  },
                  toggleContext(subject, context) {
                    let key = subject + '_' + context;

                    let index = this.expandedContexts.indexOf(key);

                    if (index > -1) {
                      this.expandedContexts.splice(index, 1);
                    } else {
                      this.expandedContexts.push(key)
                    }
                  },
                  toggleLog(runInfo) {
                    let index = this.shownLogs.indexOf(runInfo);

                    if (index > -1) {
                      this.shownLogs.splice(index, 1);
                    } else {
                      this.shownLogs.push(runInfo)
                    }
                  },
                  collapseAll() {
                    this.expandedContexts = [];
                  },
                  expandAll() {
                    this.expandedContexts = this.spectreReport.run_infos
                      .map(x => x.subject + '_' + (x.context || '[main]'))
                      .distinct();
                  }
                }
              }).mount('#app')
            </script>
          </body>
        </html>
      HTML

      Dir.mkdir @config['out_path'] unless Dir.exist? @config['out_path']

      file_path = File.join(@config['out_path'], "spectre-html_#{now.strftime('%s')}.html")

      File.write(file_path, html_str)
    end
  end
end
