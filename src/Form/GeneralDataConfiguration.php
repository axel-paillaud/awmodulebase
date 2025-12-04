<?php
/**
 * Copyright since 2007 PrestaShop SA and Contributors
 * PrestaShop is an International Registered Trademark & Property of PrestaShop SA
 *
 * NOTICE OF LICENSE
 *
 * This source file is subject to the Academic Free License version 3.0
 * that is bundled with this package in the file LICENSE.md.
 * It is also available through the world-wide-web at this URL:
 * https://opensource.org/licenses/AFL-3.0
 * If you did not receive a copy of the license and are unable to
 * obtain it through the world-wide-web, please send an email
 * to license@prestashop.com so we can send you a copy immediately.
 *
 * @author    Axelweb <contact@axelweb.fr>
 * @copyright 2007-2024 Axelweb
 * @license   http://opensource.org/licenses/afl-3.0.php  Academic Free License (AFL 3.0)
 */

declare(strict_types=1);

namespace Axelweb\AwModuleBase\Form;

use PrestaShop\PrestaShop\Core\Configuration\DataConfigurationInterface;
use PrestaShop\PrestaShop\Core\ConfigurationInterface;

/**
 * Configuration is used to save data to configuration table and retrieve from it.
 */
final class GeneralDataConfiguration implements DataConfigurationInterface
{
    public const AWMODULEBASE_SAMPLE_CONFIG = 'AWMODULEBASE_SAMPLE_CONFIG';

    /**
     * @var ConfigurationInterface
     */
    private $configuration;

    public function __construct(ConfigurationInterface $configuration)
    {
        $this->configuration = $configuration;
    }

    public function getConfiguration(): array
    {
        return [
            'sample_config' => (string) $this->configuration->get(static::AWMODULEBASE_SAMPLE_CONFIG),
        ];
    }

    public function updateConfiguration(array $configuration): array
    {
        $errors = [];

        // Quick normalisation
        $sampleConfig = isset($configuration['sample_config']) ? trim((string) $configuration['sample_config']) : '';

        if (!$this->validateConfiguration(['sample_config' => $sampleConfig])) {
            $errors[] = 'Invalid configuration payload.';

            return $errors;
        }

        // Validation (exemple)
        if ($sampleConfig !== '' && \strlen($sampleConfig) > 255) {
            $errors[] = 'Sample configuration is too long.';
        }

        if (!empty($errors)) {
            return $errors;
        }

        // Persist
        $this->configuration->set(static::AWMODULEBASE_SAMPLE_CONFIG, $sampleConfig);

        // empty = ok
        return $errors;
    }

    /**
     * Ensure the parameters passed are valid.
     *
     * @return bool Returns true if no exception are thrown
     */
    public function validateConfiguration(array $configuration): bool
    {
        return isset($configuration['sample_config']);
    }
}
